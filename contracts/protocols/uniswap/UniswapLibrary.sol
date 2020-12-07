// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IUniswapV2Pair.sol";

library UniswapLibrary {
  using SafeMath for uint256;

  function isLPToken(address token) internal view returns (bool) {
    try IUniswapV2Pair(token).token0() returns (ERC20 token0) {
      return address(token0) != address(0);
    } catch {
      return false;
    }
  }

  function calculateSwapInAmount(uint256 reserveIn, uint256 userIn) internal pure returns (uint256 amount) {
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
