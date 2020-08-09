pragma solidity >=0.6.2 <0.7.0;

import "../../tokens/Wrapped777.sol";
import "../../Receiver.sol";
import "./IUniswapWrapperFactory.sol";
import "./UniswapWrapper.sol";

contract UniswapWrapperFactory is Receiver, IUniswapWrapperFactory {
  using Address for address;

  bytes32 public constant WRAPPER_BYTECODE_HASH = keccak256(type(UniswapWrapper).creationCode);

  address private immutable router;
  address private _nextToken;

  event ExchangeCreated(address token);

  constructor(address _uniswapRouter) public {
    router = _uniswapRouter;
  }

  function calculateExchangeAddress(address token) public view returns (address calculatedAddress) {
    calculatedAddress = address(uint(keccak256(abi.encodePacked(
      byte(0xff),
      address(this),
      bytes32(uint(token)),
      WRAPPER_BYTECODE_HASH
    ))));
  }

  function createExchange(address token) public {
    _nextToken = token;
    new UniswapWrapper{salt: bytes32(uint(token))}();
    _nextToken = address(0);

    emit ExchangeCreated(token);
  }

  function getExchangeAddress(address token) public returns (address wrapperAddress) {
    wrapperAddress = calculateExchangeAddress(token);

    if(!wrapperAddress.isContract()) {
      createExchange(token);
      assert(wrapperAddress.isContract());
    }
  }

  function uniswapRouter() external override view returns (address) {
    return router;
  }

  function nextToken() external override view returns (address) {
    return _nextToken;
  }

  function _tokensReceived(IERC777, address, uint256, bytes memory) internal override {
    revert('Receiving tokens not allowed');
  }
}
