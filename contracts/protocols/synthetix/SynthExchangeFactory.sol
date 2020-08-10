pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "../../tokens/Wrapped777.sol";
import "./ISynthExchangeFactory.sol";
import "./SynthExchange.sol";

contract SynthExchangeFactory is ISynthExchangeFactory {
  using Address for address;

  address private _snx;
  address private _uniswapRouter;
  address private _nextWrapper;

  bytes32 public constant EXCHANGE_BYTECODE_HASH = keccak256(type(SynthExchange).creationCode);

  event ExchangeCreated(address token);

  constructor(address __snx, address __uniswapRouter) public {
    _snx = __snx;
    _uniswapRouter = __uniswapRouter;
  }

  function createExchange(address outputWrapper) public {    
    _nextWrapper = outputWrapper;
    new SynthExchange{salt: bytes32(uint(outputWrapper))}();
    _nextWrapper = address(0);

    emit ExchangeCreated(outputWrapper);
  }

  function calculateExchangeAddress(address outputWrapper) public view returns (address calculatedAddress) { 
    calculatedAddress = address(uint(keccak256(abi.encodePacked(
      byte(0xff),
      address(this),
      bytes32(uint(outputWrapper)),
      EXCHANGE_BYTECODE_HASH
    ))));
  }

  function getExchangeAddress(address outputWrapper) public returns (address wrapperAddress) {
    wrapperAddress = calculateExchangeAddress(outputWrapper);

    if(!wrapperAddress.isContract()) {
      createExchange(outputWrapper);
      assert(wrapperAddress.isContract());
    }
  }

  function snx() external override view returns (address) {
    return _snx;
  }

  function uniswapRouter() external override view returns (address) {
    return _uniswapRouter;
  }

  function nextWrapper() external override view returns (address) {
    return _nextWrapper;
  }
}
