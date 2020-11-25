pragma solidity >=0.6.2 <0.7.0;

interface IAdapterFactory {
  event AdapterCreated(address poolWrapper);

  function calculateAdapterAddress(address poolWrapper) external view returns (address);

  function createAdapter(address poolWrapper) external;

  function getAdapterAddress(address poolWrapper) external returns (address);
}
