pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./IWrapped777.sol";
import "../Receiver.sol";

contract Unwrapper is Receiver {
  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory /*data*/) internal override {
    IWrapped777(address(_token)).unwrapTo(amount, from);
  }
}
