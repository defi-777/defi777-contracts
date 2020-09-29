pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../tokens/Wrapped777.sol";
import "../../Receiver.sol";
import "../../InfiniteApprove.sol";
import "../../interfaces/IWETH.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "./IUniswapAdapterFactory.sol";


contract UniswapPoolAdapter is Receiver, InfiniteApprove {
  using SafeMath for uint256;

  Wrapped777 public immutable wrapper;
  IUniswapV2Pair public immutable pool;

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

    weth = factory.uniswapRouter().WETH();
  }

  receive() external payable {
    if (address(token0) != weth && address(token1) != weth) {
      revert('NoETH');
    }

    IWETH(weth).deposit{ value: msg.value }();

    swapHalfAddLiquidityAndReturn(weth, msg.value, msg.sender);
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
      revert("Invalid");
    }
  }

  function swapHalfAddLiquidityAndReturn(address token, uint256 amount, address recipient) private {
    (uint256 outputAmount, uint256 keepAmount) = swapHalf(token, amount);

    (uint256 amount0, uint256 amount1) = token == address(token0)
      ? (keepAmount, outputAmount)
      : (outputAmount, keepAmount);

    uint256 poolTokens = addLiquidity(amount0, amount1);
    wrapAndReturn(recipient, poolTokens);
  }

  function swapHalf(address input, uint256 amount) private returns (uint256 outputAmount, uint256 keepAmount) {
    (uint256 res0, uint256 res1, ) = pool.getReserves();

    uint256 swapReserve = input == address(token0) ? res0 : res1;
    uint256 outReserve = input == address(token0) ? res1 : res0;

    uint256 swapAmount = calculateSwapInAmount(swapReserve, amount);
    keepAmount = amount - swapAmount;
    ERC20(input).transfer(address(pool), swapAmount);

    outputAmount = getAmountOut(swapAmount, swapReserve, outReserve);
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

  function wrapAndReturn(address recipient, uint256 amount) private {
    infiniteApprove(wrapper.token(), address(wrapper), amount);
    wrapper.wrapTo(amount, recipient);
  }

  function calculateSwapInAmount(uint256 reserveIn, uint256 userIn) public pure returns (uint256 amount) {
    amount = sqrt(reserveIn.mul(userIn.mul(3988000) + reserveIn.mul(3988009))).sub(reserveIn.mul(1997)) / 1994;

    if (amount == 0) {
      amount = userIn / 2;
    }
  }

  // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
  function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
    uint amountInWithFee = amountIn.mul(997);
    uint numerator = amountInWithFee.mul(reserveOut);
    uint denominator = reserveIn.mul(1000).add(amountInWithFee);
    amountOut = numerator / denominator;
  }

  function sqrt(uint256 y) internal pure returns (uint256 z) {
    if (y > 3) {
      z = y;
      uint256 x = y / 2 + 1;
      while (x < z) {
        z = x;
        x = (y / x + x) / 2;
      }
    } else if (y != 0) {
      z = 1;
    }
    // else z = 0
  }
}
