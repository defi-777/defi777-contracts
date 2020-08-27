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

  bytes32 public constant WRAPPER_BYTECODE_HASH = keccak256(type(BalancerPool).creationCode);

  event WrapperCreated(address pool);

  constructor(address __weth) public {
    _weth = __weth;
  }

  function calculateWrapperAddress(address pool) public view returns (address calculatedAddress) {
    calculatedAddress = address(uint(keccak256(abi.encodePacked(
      byte(0xff),
      address(this),
      bytes32(uint(pool)),
      WRAPPER_BYTECODE_HASH
    ))));
  }

  function createWrapper(address pool) public {
    _nextToken = pool;
    new BalancerPool{salt: bytes32(uint(pool))}();
    _nextToken = address(0);

    emit WrapperCreated(pool);
  }

  function getWrapperAddress(address pool) public returns (address wrapperAddress) {
    wrapperAddress = calculateWrapperAddress(pool);

    if(!wrapperAddress.isContract()) {
      createWrapper(pool);
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
