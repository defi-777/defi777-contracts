// SPDX-License-Identifier: MIT
pragma solidity ^0.6.2;

interface ICurveMinter {
  function token() external view returns (address);

  function mint(address gague) external;
}
