pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IAddressBook.sol";

contract AddressBook is Ownable, IAddressBook {
  IAddressBook public defaultFactory;

  mapping(address => address) public entries;

  event EntrySet(address token, address wrapper);
  event DefaultFactorySet(address factory);

  constructor(IAddressBook _defaultFactory) public {
    defaultFactory = _defaultFactory;
    emit DefaultFactorySet(address(defaultFactory));
  }

  function calculateWrapperAddress(address token) external view override returns (address calculatedAddress) {
    if (entries[token] != address(0)) {
      return entries[token];
    }

    return defaultFactory.calculateWrapperAddress(token);
  }

  function getWrapperAddress(address token) external override returns (address wrapperAddress) {
    if (entries[token] != address(0)) {
      return entries[token];
    }

    return defaultFactory.getWrapperAddress(token);
  }

  function setEntry(address token, address wrapper) external onlyOwner {
    entries[token] = wrapper;
    emit EntrySet(token, wrapper);
  }

  function setDefaultFactory(address newFactory) external onlyOwner {
    defaultFactory = IAddressBook(newFactory);
    emit DefaultFactorySet(newFactory);
  }
}
