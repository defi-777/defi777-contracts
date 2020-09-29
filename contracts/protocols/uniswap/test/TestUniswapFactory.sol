pragma solidity >=0.6.2 <0.7.0;

import "../interfaces/IUniswapV2Factory.sol";

contract TestUniswapFactory is IUniswapV2Factory {
  function getPair(address tokenA, address tokenB) external override view returns (address pair) {}
}
