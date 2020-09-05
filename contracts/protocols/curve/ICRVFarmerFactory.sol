// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

interface ICRVFarmerFactory {
  function nextToken() external view returns (address);
  function nextGague() external view returns (address);
  function yieldAdapterFactoryAndRewards() external view returns(address, address[] memory);
}
