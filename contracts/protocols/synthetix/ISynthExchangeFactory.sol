pragma solidity >=0.6.2 <0.7.0;

interface ISynthExchangeFactory {
  function snx() external view returns (address);
  function uniswapRouter() external view returns (address);
  function nextWrapper() external view returns (address);
}
