pragma solidity >=0.6.2 <0.7.0;

import "./Receiver.sol";

abstract contract GuardedReceiver is Receiver {
  mapping(address => bool) private whitelistedTokens;

  function whitelistReceiveToken(address token) internal {
    whitelistedTokens[token] = true;
  }

  function _canReceive(address token) internal override {
    require(whitelistedTokens[token], 'NOT-ALLOWED');
  }
}
