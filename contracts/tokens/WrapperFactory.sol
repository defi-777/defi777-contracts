pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Wrapped777.sol";

contract WrapperFactory {
  mapping(address => Wrapped777) private wrappers;

  function getWrapper(address token) external view returns (Wrapped777) {
    return wrappers[token];
  }

  function create(address token) external {
    require(address(wrappers[token]) == address(0));

    Wrapped777 wrapper = new Wrapped777{salt: bytes32(0)}(ERC20(token));
    wrappers[token] = wrapper;
  }
}
