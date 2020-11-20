// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "../../tokens/Wrapped777.sol";
import "../../Receiver.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "./IUniswapAdapterFactory.sol";
import "./UniswapAdapter.sol";

contract UniswapAdapterFactory is Receiver, IUniswapAdapterFactory {
  using Address for address;

  bytes32 public constant ADAPTER_BYTECODE_HASH = keccak256(type(UniswapAdapter).creationCode);

  address private immutable router;
  address private _nextToken;

  event AdapterCreated(address token);

  constructor(address _uniswapRouter) public {
    router = _uniswapRouter;
  }

  function calculateAdapterAddress(address token) public view returns (address calculatedAddress) {
    calculatedAddress = address(uint(keccak256(abi.encodePacked(
      byte(0xff),
      address(this),
      bytes32(uint(token)),
      ADAPTER_BYTECODE_HASH
    ))));
  }

  function createAdapter(address token) public {
    _nextToken = token;
    new UniswapAdapter{salt: bytes32(uint(token))}();
    _nextToken = address(0);

    emit AdapterCreated(token);
  }

  function getAdapterAddress(address token) public returns (address adapterAddress) {
    adapterAddress = calculateAdapterAddress(token);

    if(!adapterAddress.isContract()) {
      createAdapter(token);
      assert(adapterAddress.isContract());
    }
  }

  function uniswapRouter() external override view returns (IUniswapV2Router01) {
    return IUniswapV2Router01(router);
  }

  function nextToken() external override view returns (address) {
    return _nextToken;
  }

  function _tokensReceived(IERC777, address, uint256, bytes memory) internal override {
    revert('Receiving tokens not allowed');
  }
}
