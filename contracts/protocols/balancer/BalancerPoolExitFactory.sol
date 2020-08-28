pragma solidity >=0.6.3 <0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./BalancerPoolExit.sol";
import "./IBalancerPoolFactory.sol";


contract BalancerPoolExitFactory is IBalancerPoolFactory {
  using Address for address;

  address private _nextToken;
  address private immutable _weth;

  bytes32 public constant ADAPTER_BYTECODE_HASH = keccak256(type(BalancerPoolExit).creationCode);

  event AdapterCreated(address wrapper);

  constructor(address __weth) public {
    _weth = __weth;
  }

  function calculateWrapperAddress(address wrapper) public view returns (address calculatedAddress) {
    calculatedAddress = address(uint(keccak256(abi.encodePacked(
      byte(0xff),
      address(this),
      bytes32(uint(wrapper)),
      ADAPTER_BYTECODE_HASH
    ))));
  }

  function createWrapper(address wrapper) public {
    _nextToken = wrapper;
    new BalancerPoolExit{salt: bytes32(uint(wrapper))}();
    _nextToken = address(0);

    emit AdapterCreated(wrapper);
  }

  function getWrapperAddress(address wrapper) public returns (address wrapperAddress) {
    wrapperAddress = calculateWrapperAddress(wrapper);

    if(!wrapperAddress.isContract()) {
      createWrapper(wrapper);
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
