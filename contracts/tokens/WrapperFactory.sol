pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./IWrapperFactory.sol";
import "./Wrapped777.sol";


contract WrapperFactory is IWrapperFactory {
  using Address for address;

  address private _nextToken;

  bytes32 constant WRAPPER_BYTECODE_HASH = keccak256(type(Wrapped777).creationCode);

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
    new Wrapped777{salt: bytes32(uint(token))}();
    _nextToken = address(0);
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
}
