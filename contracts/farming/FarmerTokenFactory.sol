pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./FarmerToken.sol";
import "./IFarmerTokenFactory.sol";


contract FarmerTokenFactory is Ownable, IFarmerTokenFactory {
  using Address for address;

  address private _nextToken;
  address private immutable _adapterFactory;

  bytes32 public constant WRAPPER_BYTECODE_HASH = keccak256(type(FarmerToken).creationCode);

  event WrapperCreated(address token);

  constructor(address __adapterFactory) public {
    _adapterFactory = __adapterFactory;
  }

  function calculateWrapperAddress(address token) public view returns (address calculatedAddress) {
    calculatedAddress = address(uint(keccak256(abi.encodePacked(
      byte(0xff),
      address(this),
      bytes32(uint(token)),
      WRAPPER_BYTECODE_HASH
    ))));
  }

  function createWrapper(address token) public {
    _nextToken = token;
    new FarmerToken{salt: bytes32(uint(token))}();
    _nextToken = address(0);

    emit WrapperCreated(token);
  }

  function getWrapperAddress(address token) public returns (address wrapperAddress) {
    wrapperAddress = calculateWrapperAddress(token);

    if(!wrapperAddress.isContract()) {
      createWrapper(token);
      assert(wrapperAddress.isContract());
    }
  }

  function nextToken() external override view returns (address) {
    return _nextToken;
  }

  function adapterFactory() external override view returns (address) {
    return _adapterFactory;
  }
}
