pragma solidity >=0.6.2 <0.7.0;

import "./IUniswapV2Router01.sol";

interface IUniswapWrapperFactory {
  function nextToken() external view returns (address);

  function uniswapRouter() external view returns (IUniswapV2Router01);
}
