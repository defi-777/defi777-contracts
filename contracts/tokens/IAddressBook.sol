pragma solidity >=0.6.2 <0.7.0;

interface IAddressBook {
  function getWrapperAddress(address token) external returns (address wrapperAddress);

  function calculateWrapperAddress(address token) external view returns (address calculatedAddress);
}
