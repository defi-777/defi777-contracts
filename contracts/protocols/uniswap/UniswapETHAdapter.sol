// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "../../ens/ReverseENS.sol";
import "../../tokens/Wrapped777.sol";
import "../../interfaces/IWETH.sol";
import "../../Receiver.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./UniswapLibrary.sol";

contract UniswapETHAdapter is Receiver, ReverseENS {
  using SafeMath for uint256;

  IUniswapV2Factory public immutable uniswapFactory;
  address private immutable weth;

  constructor(IUniswapV2Router01 _router) public {
    weth = _router.WETH();
    uniswapFactory = _router.factory();
  }

  receive() external payable {
    require(msg.sender == weth);
  }

  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory /*data*/) internal override {
    // Todo: support non-wrapped 777 tokens
    Wrapped777 inputWrapper = Wrapped777(address(_token));
    ERC20 unwrappedInput = inputWrapper.token();

    if (isUniswapLPToken(address(unwrappedInput))) {
      burnAndSwapLPToken(inputWrapper, IUniswapV2Pair(address(unwrappedInput)), from, amount);
      return;
    }

    uint unwrappedBalance = inputWrapper.unwrap(amount);

    uint256 wethAmount = executeSwap(address(unwrappedInput), weth, unwrappedBalance, address(this));
    require(wethAmount > 0, "NO_PAIR");

    IWETH(weth).withdraw(wethAmount);
    TransferHelper.safeTransferETH(from, wethAmount);
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

    (address keepToken, address swapToken) = weth == token0
      ? (token0, token1)
      : (token1, token0);

    if (keepToken != weth) {
      return doubleSwap(token0, amount0, token1, amount1, recipient);
    }

    (uint256 keepAmount, uint256 swapAmount) = weth == token0
      ? (amount0, amount1)
      : (amount1, amount0);

    uint256 outputAmount = executeSwap(swapToken, keepToken, swapAmount, address(this));

    uint256 totalWETH = outputAmount + keepAmount;
    IWETH(weth).withdraw(totalWETH);
    TransferHelper.safeTransferETH(recipient, totalWETH);
  }

  function doubleSwap(address token0, uint256 amount0, address token1, uint256 amount1, address recipient) private {
    uint256 swap0Amt = executeSwap(token0, weth, amount0, amount0, address(this));
    uint256 swap1Amt = executeSwap(token1, weth, amount1, amount1, address(this));

    uint256 totalWETH = swap0Amt + swap1Amt;
    IWETH(weth).withdraw(totalWETH);
    TransferHelper.safeTransferETH(recipient, totalWETH);
  }
}
