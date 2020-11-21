// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

interface IBalancerPoolFactory {
  function nextToken() external view returns (address);
  function weth() external view returns (address);
}
