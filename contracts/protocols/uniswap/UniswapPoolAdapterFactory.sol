// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "../../tokens/Wrapped777.sol";
import "../../Receiver.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "./IUniswapAdapterFactory.sol";
import "./UniswapPoolAdapter.sol";

contract UniswapPoolAdapterFactory is Receiver, IUniswapAdapterFactory {
  using Address for address;

  bytes32 public constant POOL_ADAPTER_BYTECODE_HASH = keccak256(type(UniswapPoolAdapter).creationCode);

  address private _nextToken;
  address private immutable _router;

  event AdapterCreated(address poolWrapper);

  constructor(address __router) public {
    _router = __router;
  }

  function calculateAdapterAddress(address poolWrapper) public view returns (address calculatedAddress) {
    calculatedAddress = address(uint(keccak256(abi.encodePacked(
      byte(0xff),
      address(this),
      bytes32(uint(poolWrapper)),
      POOL_ADAPTER_BYTECODE_HASH
    ))));
  }

  function createAdapter(address poolWrapper) public {
    _nextToken = poolWrapper;
    new UniswapPoolAdapter{salt: bytes32(uint(poolWrapper))}();
    _nextToken = address(0);

    emit AdapterCreated(poolWrapper);
  }

  function getAdapterAddress(address poolWrapper) public returns (address wrapperAddress) {
    wrapperAddress = calculateAdapterAddress(poolWrapper);

    if(!wrapperAddress.isContract()) {
      createAdapter(poolWrapper);
      assert(wrapperAddress.isContract());
    }
  }

  function nextToken() external override view returns (address) {
    return _nextToken;
  }

  function uniswapRouter() external override view returns (IUniswapV2Router01) {
    return IUniswapV2Router01(_router);
  }

  function _tokensReceived(IERC777, address, uint256, bytes memory) internal override {
    revert('Receiving tokens not allowed');
  }
}
