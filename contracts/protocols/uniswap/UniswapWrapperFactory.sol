pragma solidity >=0.6.2 <0.7.0;

import "../../tokens/Wrapped777.sol";
import "./UniswapWrapper.sol";

contract UniswapWrapperFactory {
  address public uniswapRouter;
  mapping(address => UniswapWrapper) private wrappers;

  constructor(address _uniswapRouter) public {
    uniswapRouter = _uniswapRouter;
  }

  function getWrapper(address token) external view returns (UniswapWrapper) {
    return wrappers[token];
  }

  function createExchange(Wrapped777 token) public {
    UniswapWrapper wrapper = new UniswapWrapper{salt: bytes32(0)}(token, uniswapRouter);
    wrappers[address(token)] = wrapper;
  }
}
