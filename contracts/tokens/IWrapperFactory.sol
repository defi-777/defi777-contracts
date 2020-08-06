pragma solidity >=0.6.2 <0.7.0;

interface IWrapperFactory {
  function nextToken() external view returns (address);
}
