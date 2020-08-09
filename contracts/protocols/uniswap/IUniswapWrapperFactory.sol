pragma solidity >=0.6.2 <0.7.0;

interface IUniswapWrapperFactory {
  function nextToken() external view returns (address);

  function uniswapRouter() external view returns (address);
}
