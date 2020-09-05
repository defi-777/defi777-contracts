// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./FarmerToken.sol";
import "./IFarmerTokenFactory.sol";


contract FarmerTokenFactory is IFarmerTokenFactory {
  using Address for address;

  address private _nextToken;
  address[] private _rewards;
  address private immutable _adapterFactory;

  bytes32 public constant WRAPPER_BYTECODE_HASH = keccak256(type(FarmerToken).creationCode);

  event WrapperCreated(address indexed token, address wrapper);

  constructor(address __adapterFactory) public {
    _adapterFactory = __adapterFactory;
  }

  function calculateWrapperAddress(address token, address[] memory rewards)
    public view returns (address calculatedAddress) {
    calculatedAddress = address(uint(keccak256(abi.encodePacked(
      byte(0xff),
      address(this),
      keccak256(abi.encodePacked(token, rewards)),
      WRAPPER_BYTECODE_HASH
    ))));
  }

  function createWrapper(address token, address[] memory rewards) public {
    _nextToken = token;
    _rewards = rewards;

    FarmerToken wrapper = new FarmerToken{salt: keccak256(abi.encodePacked(token, rewards))}();

    _nextToken = address(0);
    _rewards = new address[](0);

    emit WrapperCreated(token, address(wrapper));
  }

  function getWrapperAddress(address token, address[] memory rewards)
    public returns (address wrapperAddress) {
    wrapperAddress = calculateWrapperAddress(token, rewards);

    if(!wrapperAddress.isContract()) {
      createWrapper(token, rewards);
      assert(wrapperAddress.isContract());
    }
  }

  function nextToken() external override view returns (address) {
    return _nextToken;
  }

  function yieldAdapterFactoryAndRewards() external override view returns(address, address[] memory) {
    return (_adapterFactory, _rewards);
  }
}
