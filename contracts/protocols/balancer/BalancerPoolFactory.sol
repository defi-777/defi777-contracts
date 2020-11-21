// SPDX-License-Identifier: MIT
pragma solidity >=0.6.3 <0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./BalancerPool.sol";
import "./IBalancerPoolFactory.sol";


contract BalancerPoolFactory is IBalancerPoolFactory {
  using Address for address;

  address private _nextToken;
  address private immutable _weth;

  bytes32 public constant ADAPTER_BYTECODE_HASH = keccak256(type(BalancerPool).creationCode);

  event AdapterCreated(address pool);

  constructor(address __weth) public {
    _weth = __weth;
  }

  function calculateAdapterAddress(address pool) public view returns (address calculatedAddress) {
    calculatedAddress = address(uint(keccak256(abi.encodePacked(
      byte(0xff),
      address(this),
      bytes32(uint(pool)),
      ADAPTER_BYTECODE_HASH
    ))));
  }

  function createAdapter(address pool) public {
    _nextToken = pool;
    new BalancerPool{salt: bytes32(uint(pool))}();
    _nextToken = address(0);

    emit AdapterCreated(pool);
  }

  function getAdapterAddress(address pool) public returns (address wrapperAddress) {
    wrapperAddress = calculateAdapterAddress(pool);

    if(!wrapperAddress.isContract()) {
      createAdapter(pool);
      assert(wrapperAddress.isContract());
    }
  }

  function nextToken() external override view returns (address) {
    return _nextToken;
  }

  function weth() external override view returns (address) {
    return _weth;
  }
}
