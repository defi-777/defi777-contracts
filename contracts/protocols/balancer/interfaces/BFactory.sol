// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

interface BFactory {
  function isBPool(address b) external view returns (bool);
}
