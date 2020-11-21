// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./CRVFarmerToken.sol";
import "./ICRVFarmerFactory.sol";


contract CRVFarmerTokenFactory is ICRVFarmerFactory {
  using Address for address;

  address private _nextToken;
  address private _nextGague;
  address private immutable _crvWrapper;
  address private immutable _adapterFactory;

  bytes32 public constant WRAPPER_BYTECODE_HASH = keccak256(type(CRVFarmerToken).creationCode);

  event WrapperCreated(address indexed token, address gague);

  constructor(address crvWrapper, address __adapterFactory) public {
    _crvWrapper = crvWrapper;
    _adapterFactory = __adapterFactory;
  }

  function calculateWrapperAddress(address token, address gague) public view returns (address calculatedAddress) {
    calculatedAddress = address(uint(keccak256(abi.encodePacked(
      byte(0xff),
      address(this),
      keccak256(abi.encodePacked(token, gague)),
      WRAPPER_BYTECODE_HASH
    ))));
  }

  function createWrapper(address token, address gague) public {
    _nextToken = token;
    _nextGague = gague;

    new CRVFarmerToken{salt: keccak256(abi.encodePacked(token, gague))}();

    _nextToken = address(0);
    _nextGague = address(0);

    emit WrapperCreated(token, gague);
  }

  function getWrapperAddress(address token, address gague) public returns (address wrapperAddress) {
    wrapperAddress = calculateWrapperAddress(token, gague);

    if(!wrapperAddress.isContract()) {
      createWrapper(token, gague);
      assert(wrapperAddress.isContract());
    }
  }

  function nextToken() external override view returns (address) {
    return _nextToken;
  }

  function nextGague() external override view returns (address) {
    return _nextGague;
  }

  function yieldAdapterFactoryAndRewards() external override view returns(address, address[] memory) {
    address[] memory _rewards = new address[](1);
    _rewards[0] = _crvWrapper;
    return (_adapterFactory, _rewards);
  }
}
