// SPDX-License-Identifier: MIT
pragma solidity ^0.6.2;

interface ICurveGague {
  function deposit(uint256 amount) external;

  function withdraw(uint256 amount) external;
}
