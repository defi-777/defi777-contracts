// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

interface IFarmerToken {
  function rewardTokens() external view returns (address[] memory);
  function getWrapper(address token) external returns (address);
  function rewardBalance(address token, address user) external view returns (uint256);
  function withdrawFrom(address token, address from, uint256 amount) external;
  function getRewardAdapter(address rewardToken) external view returns (address);
}
