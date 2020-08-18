pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";

contract MaliciousUpgradeToken {
  address public token;

  constructor(address _token) public {
    token = _token;
  }

  function callReceiveHook(IERC777Recipient recipient) external {
    recipient.tokensReceived(msg.sender, msg.sender, address(recipient), 1 ether, "", "");
  } 

  function transfer(address, uint256) external returns (bool success) {
    token = token;
    success = true;
  }
}
