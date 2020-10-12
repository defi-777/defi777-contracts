// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "../../tokens/Wrapped777.sol";
import "../../Receiver.sol";
import "../../InfiniteApprove.sol";
import "../../interfaces/IWETH.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./IUniswapAdapterFactory.sol";

contract UniswapAdapter is Receiver, InfiniteApprove {
  using SafeMath for uint256;

  Wrapped777 public immutable wrapper;
  IUniswapV2Router01 public immutable router;
  IUniswapV2Factory public immutable uniswapFactory;
  address private immutable weth;

  constructor() public {
    IUniswapAdapterFactory factory = IUniswapAdapterFactory(msg.sender);
    Wrapped777 _wrapper = Wrapped777(factory.nextToken());
    wrapper = _wrapper;
    IUniswapV2Router01 _router = factory.uniswapRouter();
    weth = _router.WETH();
    router = _router;
    uniswapFactory = _router.factory();
    infiniteApprove(_wrapper.token(), address(_wrapper), 1);
  }

  receive() external payable {
    if (msg.sender == weth) {
      return;
    }

    IWETH(weth).deposit{ value: msg.value }();

    ERC20 outputToken = wrapper.token();
    uint256 outputAmount = executeSwap(weth, address(outputToken), msg.value, address(this));
    require (outputAmount > 0, "NO_PAIR");

    wrapAndReturn(msg.sender, outputAmount);
  }

  /**
    * Ex: Assume this is a Dai Uniswap contract
    * If Dai777 is sent to this, it will swap to ETH
    * If USDC777 is sent to this, it wall swap to Dai777
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
      ERC20 outputToken = wrapper.token();
      uint256 outputAmount = executeSwap(address(unwrappedInput), address(outputToken), unwrappedBalance, address(this));

      if (outputAmount == 0) {
        address wethOutPair = uniswapFactory.getPair(weth, address(outputToken));
        uint256 wethAmount = executeSwap(address(unwrappedInput), weth, unwrappedBalance, wethOutPair);
        outputAmount = executeSwap(weth, address(outputToken), wethAmount, 0, address(this));
      }

      require(outputAmount > 0, "NO_PAIR");

      wrapAndReturn(from, outputAmount);
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

    outputAmount = getAmountOut(swapAmount, reserveIn, reserveOut);
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
    ERC20 outputToken = wrapper.token();
    address token0 = address(pair.token0());
    address token1 = address(pair.token1());

    inputWrapper.unwrapTo(amount, address(pair));

    (uint amount0, uint amount1) = pair.burn(address(this));

    (address keepToken, address swapToken) = address(outputToken) == token0
      ? (token0, token1)
      : (token1, token0);
    require(keepToken == address(outputToken), 'BAD_PAIR');

    (uint256 swapAmount, uint256 keepAmount) = address(outputToken) == token0
      ? (amount0, amount1)
      : (amount1, amount0);

    executeSwap(swapToken, keepToken, swapAmount, address(wrapper));
    outputToken.transfer(address(wrapper), keepAmount);

    wrapper.gulp(recipient);
  }

  function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
    require(amountIn > 0);
    require(reserveIn > 0 && reserveOut > 0);
    uint amountInWithFee = amountIn.mul(997);
    uint numerator = amountInWithFee.mul(reserveOut);
    uint denominator = reserveIn.mul(1000).add(amountInWithFee);
    amountOut = numerator / denominator;
  }


  function wrapAndReturn(address recipient, uint256 amount) private {
    infiniteApprove(wrapper.token(), address(wrapper), amount);
    wrapper.wrapTo(amount, recipient);
  }
}
