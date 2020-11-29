// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

interface IAdapterFactory {
  event AdapterCreated(address outputWrapper);

  function calculateAdapterAddress(address outputWrapper) external view returns (address);

  function createAdapter(address outputWrapper) external;

  function getAdapterAddress(address outputWrapper) external returns (address);
}
