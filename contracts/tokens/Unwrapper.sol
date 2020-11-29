// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "./IWrapped777.sol";
import "../Receiver.sol";
import "../ens/ReverseENS.sol";

contract Unwrapper is Receiver, ReverseENS {
  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory /*data*/) internal override {
    IWrapped777(address(_token)).unwrapTo(amount, from);
  }
}
