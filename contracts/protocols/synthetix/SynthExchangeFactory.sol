pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "../../tokens/Wrapped777.sol";
import "./SynthExchange.sol";

contract SynthExchangeFactory {
  using Address for address;

  address public snx;
  address public uniswapRouter;

  constructor(address _snx, address _uniswapRouter) public {
    snx = _snx;
    uniswapRouter = _uniswapRouter;
  }

  function createExchange(address outputWrapper) public {    
    new SynthExchange{salt: bytes32(0)}(Wrapped777(outputWrapper), snx, uniswapRouter);
  }

  function calculateExchangeAddress(address outputWrapper) public view returns (address calculatedAddress) { 
    calculatedAddress = address(uint(keccak256(abi.encodePacked(
      byte(0xff),
      address(this),
      bytes32(0),
      keccak256(abi.encodePacked(
        type(SynthExchange).creationCode,
        uint256(outputWrapper),
        uint256(snx),
        uint256(uniswapRouter)
      ))
    ))));
  }

  function getExchangeAddress(address outputWrapper) public returns (address wrapperAddress) {
    wrapperAddress = calculateExchangeAddress(outputWrapper);

    if(!wrapperAddress.isContract()) {
      createExchange(outputWrapper);
      assert(wrapperAddress.isContract());
    }
  }
}
