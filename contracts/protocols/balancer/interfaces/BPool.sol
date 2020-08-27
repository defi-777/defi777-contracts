pragma solidity >=0.6.2 <0.7.0;

interface BPool {
  function getCurrentTokens() external view returns (address[] memory tokens);

  function swapExactAmountIn(
    address tokenIn,
    uint tokenAmountIn,
    address tokenOut,
    uint minAmountOut,
    uint maxPrice
  ) external returns (uint tokenAmountOut, uint spotPriceAfter);

  function getSpotPrice(address tokenIn, address tokenOut) external view returns (uint spotPrice);

  function joinswapExternAmountIn(
    address tokenIn,
    uint tokenAmountIn,
    uint minPoolAmountOut
  ) external returns (uint poolAmountOut);
}
