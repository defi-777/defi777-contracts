// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "../../ens/ReverseENS.sol";
import "../../tokens/Wrapped777.sol";
import "../../interfaces/IWETH.sol";
import "../../Receiver.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./IUniswapAdapterFactory.sol";
import "./UniswapLibrary.sol";

contract UniswapAdapter is Receiver, ReverseENS {
  using SafeMath for uint256;

  Wrapped777 public immutable wrapper;
  IUniswapV2Factory public immutable uniswapFactory;
  address private immutable weth;
  address private immutable wethOutPair;
  ERC20 private immutable outputToken;

  constructor() public {
    IUniswapAdapterFactory factory = IUniswapAdapterFactory(msg.sender);
    Wrapped777 _wrapper = Wrapped777(factory.nextToken());
    wrapper = _wrapper;
    ERC20 _outputToken = _wrapper.token();
    outputToken = _outputToken;
    IUniswapV2Router01 _router = factory.uniswapRouter();
    address _weth = _router.WETH();
    weth = _weth;

    IUniswapV2Factory _factory = _router.factory();
    uniswapFactory = _factory;
    wethOutPair = _factory.getPair(_weth, address(_outputToken));
  }

  receive() external payable {
    if (msg.sender == weth) {
      return;
    }

    IWETH(weth).deposit{ value: msg.value }();

    uint256 outputAmount = executeSwap(weth, address(outputToken), msg.value, address(wrapper));
    require (outputAmount > 0, "NO_PAIR");

    wrapper.gulp(msg.sender);
  }

  /**
    * Ex: Assume this is a Dai Uniswap contract
    * If Dai777 is sent to this, it will swap to ETH
    * If USDC777 is sent to this, it wall swap to Dai777
    * If a DAI-ETH LP token is sent to this, it will withdraw & swap into Dai777
    */
  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory /*data*/) internal override {
    // Todo: support non-wrapped 777 tokens
    Wrapped777 inputWrapper = Wrapped777(address(_token));
    ERC20 unwrappedInput = inputWrapper.token();

    if (isUniswapLPToken(address(unwrappedInput))) {
      burnAndSwapLPToken(inputWrapper, IUniswapV2Pair(address(unwrappedInput)), from, amount);
      return;
    }

    uint unwrappedBalance = inputWrapper.unwrap(amount);

    if (address(_token) == address(wrapper)) {
      uint256 wethAmount = executeSwap(address(unwrappedInput), weth, unwrappedBalance, address(this));
      require(wethAmount > 0, "NO_PAIR");

      IWETH(weth).withdraw(wethAmount);
      TransferHelper.safeTransferETH(from, wethAmount);
    } else {
      uint256 outputAmount = executeSwap(address(unwrappedInput), address(outputToken), unwrappedBalance, address(wrapper));

      if (outputAmount == 0) {
        uint256 wethAmount = executeSwap(address(unwrappedInput), weth, unwrappedBalance, wethOutPair);
        outputAmount = executeSwap(weth, address(outputToken), wethAmount, 0, address(wrapper));
      }

      require(outputAmount > 0, "NO_PAIR");

      wrapper.gulp(from);
    }
  }

  function executeSwap(address input, address out, uint256 swapAmount, address to) private returns (uint256 outputAmount) {
    return executeSwap(input, out, swapAmount, swapAmount, to);
  }

  function executeSwap(address input, address out, uint256 swapAmount, uint256 transferAmount, address to) private returns (uint256 outputAmount) {
    IUniswapV2Pair pair = IUniswapV2Pair(uniswapFactory.getPair(input, out));
    if (address(pair) == address(0)) {
      return 0;
    }

    if (transferAmount > 0) {
      TransferHelper.safeTransfer(input, address(pair), transferAmount);
    }

    address token0 = address(pair.token0());

    (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
    (uint256 reserveIn, uint256 reserveOut) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);

    outputAmount = UniswapLibrary.getAmountOut(swapAmount, reserveIn, reserveOut);
    (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), outputAmount) : (outputAmount, uint(0));

    pair.swap(amount0Out, amount1Out, to, new bytes(0));
  }

  function isUniswapLPToken(address token) private view returns (bool) {
    try IUniswapV2Pair(token).factory() returns (address factory) {
      return factory == address(uniswapFactory);
    } catch {
      return false;
    }
  }

  function burnAndSwapLPToken(Wrapped777 inputWrapper, IUniswapV2Pair pair, address recipient, uint256 amount) private {
    address token0 = address(pair.token0());
    address token1 = address(pair.token1());

    inputWrapper.unwrapTo(amount, address(pair));

    (uint amount0, uint amount1) = pair.burn(address(this));

    (address keepToken, address swapToken) = address(outputToken) == token0
      ? (token0, token1)
      : (token1, token0);

    if (keepToken != address(outputToken)) {
      return doubleSwap(token0, amount0, token1, amount1, recipient);
    }

    (uint256 keepAmount, uint256 swapAmount) = address(outputToken) == token0
      ? (amount0, amount1)
      : (amount1, amount0);

    executeSwap(swapToken, keepToken, swapAmount, address(wrapper));
    outputToken.transfer(address(wrapper), keepAmount);

    wrapper.gulp(recipient);
  }

  function doubleSwap(address token0, uint256 amount0, address token1, uint256 amount1, address recipient) private {
    uint256 wethAmount = 0;
    uint256 swap0Amt = executeSwap(token0, address(outputToken), amount0, amount0, address(wrapper));
    uint256 swap1Amt = executeSwap(token1, address(outputToken), amount1, amount1, address(wrapper));

    if (swap0Amt == 0) {
      uint256 swapAmount = executeSwap(token0, weth, amount0, wethOutPair);
      require(swapAmount > 0, 'NO-PAIR');
      wethAmount += swapAmount;
    }
    if (swap1Amt == 0) {
      uint256 swapAmount = executeSwap(token1, weth, amount1, wethOutPair);
      require(swapAmount > 0, 'NO-PAIR');
      wethAmount += swapAmount;
    }

    if (wethAmount > 0) {
      executeSwap(weth, address(outputToken), wethAmount, 0, address(wrapper));
    }

    wrapper.gulp(recipient);
  }
}
