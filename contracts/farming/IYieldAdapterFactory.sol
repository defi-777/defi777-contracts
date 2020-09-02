// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

interface IYieldAdapterFactory {
  function nextToken() external view returns (address);
  function nextReward() external view returns (address);
  function wrapperFactory() external view returns (address);
  function calculateWrapperAddress(address farmerToken, address rewardToken) external view returns (address calculatedAddress);
  function createWrapper(address farmerToken, address rewardToken) external;
  function getWrapperAddress(address farmerToken, address rewardToken) external returns (address wrapperAddress);
}
