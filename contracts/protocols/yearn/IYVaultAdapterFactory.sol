// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

interface IYVaultAdapterFactory {
  function nextWrappers() external view returns (address, address);
  function weth() external view returns (address);
}
