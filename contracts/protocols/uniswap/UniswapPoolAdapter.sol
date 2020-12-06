// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../ens/ReverseENS.sol";
import "../../tokens/Wrapped777.sol";
import "../../interfaces/IWETH.sol";
import "../../Receiver.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "./IUniswapAdapterFactory.sol";
import "./UniswapLibrary.sol";

contract UniswapPoolAdapter is Receiver, ReverseENS {
  using SafeMath for uint256;

  Wrapped777 public immutable wrapper;
  IUniswapV2Pair public immutable pool;
  IUniswapV2Factory public immutable uniswapFactory;

  ERC20 public immutable token0;
  ERC20 public immutable token1;

  address private immutable weth;

  constructor() public {
    IUniswapAdapterFactory factory = IUniswapAdapterFactory(msg.sender);
    Wrapped777 _wrapper = Wrapped777(factory.nextToken());
    wrapper = _wrapper;

    IUniswapV2Pair _pool = IUniswapV2Pair(address(_wrapper.token()));
    pool = _pool;

    token0 = _pool.token0();
    token1 = _pool.token1();

    IUniswapV2Router01 router = factory.uniswapRouter();
    weth = router.WETH();
    uniswapFactory = router.factory();
  }

  receive() external payable {

    IWETH(weth).deposit{ value: msg.value }();

    if (address(token0) == weth || address(token1) == weth) {
      swapHalfAddLiquidityAndReturn(weth, msg.value, msg.sender);
    } else {
      uint256 output = executeSwap(weth, address(token0), msg.value, address(this));
      require(output != 0, 'NO-PATH');
      swapHalfAddLiquidityAndReturn(address(token0), output, msg.sender);
    }
  }

  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory /*data*/) internal override {
    Wrapped777 inputWrapper = Wrapped777(address(_token));
    ERC20 unwrappedInput = inputWrapper.token();

    uint unwrappedBalance = inputWrapper.unwrap(amount);

    if (address(unwrappedInput) == address(token0) || address(unwrappedInput) == address(token1)) {
      // Swap half of the token so it can add liquidity
      swapHalfAddLiquidityAndReturn(address(unwrappedInput), unwrappedBalance, from);
    } else if (address(unwrappedInput) == address(pool)) {
      // If receiving an LP token wrapper, remove liquidity and send the tokens to the sender
      // Note: this sends the unwrapped tokens
      pool.burn(from);
    } else {
      swapIn(unwrappedInput, unwrappedBalance, from);
    }
  }

  function swapIn(ERC20 token, uint256 amount, address recipient) private {
    uint256 swapAmount = executeSwap(address(token), address(token0), amount, address(this));
    if (swapAmount != 0) {
      return swapHalfAddLiquidityAndReturn(address(token0), swapAmount, recipient);
    }

    swapAmount = executeSwap(address(token), address(token1), amount, address(this));
    if (swapAmount != 0) {
      return swapHalfAddLiquidityAndReturn(address(token1), swapAmount, recipient);
    }

    if (address(token0) != weth && address(token1) != weth) {
      address wethPair = uniswapFactory.getPair(weth, address(token0));
      swapAmount = executeSwap(address(token), weth, amount, wethPair);
      swapAmount = executeSwap(weth, address(token0), swapAmount, 0, address(this));

      if (swapAmount != 0) {
        return swapHalfAddLiquidityAndReturn(address(token0), swapAmount, recipient);
      }
    }

    if (swapAmount == 0) {
      revert('NO-PATH');
    }
  }

  function swapHalfAddLiquidityAndReturn(address token, uint256 amount, address recipient) private {
    (uint256 outputAmount, uint256 keepAmount) = swapHalf(token, amount);

    (uint256 amount0, uint256 amount1) = token == address(token0)
      ? (keepAmount, outputAmount)
      : (outputAmount, keepAmount);

    uint256 poolTokens = addLiquidity(amount0, amount1);

    pool.transfer(address(wrapper), poolTokens);
    wrapper.gulp(recipient);
  }

  function swapHalf(address input, uint256 amount) private returns (uint256 outputAmount, uint256 keepAmount) {
    (uint256 res0, uint256 res1, ) = pool.getReserves();

    uint256 swapReserve = input == address(token0) ? res0 : res1;
    uint256 outReserve = input == address(token0) ? res1 : res0;

    uint256 swapAmount = UniswapLibrary.calculateSwapInAmount(swapReserve, amount);
    keepAmount = amount - swapAmount;
    ERC20(input).transfer(address(pool), swapAmount);

    outputAmount = UniswapLibrary.getAmountOut(swapAmount, swapReserve, outReserve);
    (uint amount0Out, uint amount1Out) = input == address(token0)
      ? (uint(0), outputAmount)
      : (outputAmount, uint(0));
    pool.swap(amount0Out, amount1Out, address(this), new bytes(0));
  }

  function addLiquidity(uint256 amount0, uint256 amount1) private returns (uint256 poolTokens) {
    token0.transfer(address(pool), amount0);
    token1.transfer(address(pool), amount1);
    poolTokens = pool.mint(address(this));
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

    address _token0 = address(pair.token0());

    (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
    (uint256 reserveIn, uint256 reserveOut) = input == _token0 ? (reserve0, reserve1) : (reserve1, reserve0);

    outputAmount = UniswapLibrary.getAmountOut(swapAmount, reserveIn, reserveOut);
    (uint amount0Out, uint amount1Out) = input == _token0 ? (uint(0), outputAmount) : (outputAmount, uint(0));

    pair.swap(amount0Out, amount1Out, to, new bytes(0));
  }
}
