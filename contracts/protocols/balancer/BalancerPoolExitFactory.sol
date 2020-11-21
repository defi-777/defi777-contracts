// SPDX-License-Identifier: MIT
pragma solidity >=0.6.3 <0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../../tokens/IWrapperFactory.sol";
import "./BalancerPoolExit.sol";

contract BalancerPoolExitFactory is IWrapperFactory {
  using Address for address;

  address private _nextToken;

  bytes32 public constant ADAPTER_BYTECODE_HASH = keccak256(type(BalancerPoolExit).creationCode);

  event AdapterCreated(address wrapper);

  function calculateAdapterAddress(address wrapper) public view returns (address calculatedAddress) {
    calculatedAddress = address(uint(keccak256(abi.encodePacked(
      byte(0xff),
      address(this),
      bytes32(uint(wrapper)),
      ADAPTER_BYTECODE_HASH
    ))));
  }

  function createAdapter(address wrapper) public {
    _nextToken = wrapper;
    new BalancerPoolExit{salt: bytes32(uint(wrapper))}();
    _nextToken = address(0);

    emit AdapterCreated(wrapper);
  }

  function getAdapterAddress(address wrapper) public returns (address wrapperAddress) {
    wrapperAddress = calculateAdapterAddress(wrapper);

    if(!wrapperAddress.isContract()) {
      createAdapter(wrapper);
      assert(wrapperAddress.isContract());
    }
  }

  function nextToken() external override view returns (address) {
    return _nextToken;
  }
}
