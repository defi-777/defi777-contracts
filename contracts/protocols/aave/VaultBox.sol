pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract VaultBox {
  address private vault;

  constructor() public {
    vault = msg.sender;
  }

  function remove(ERC20 token, uint256 amount) external {
    require(msg.sender == vault);
    token.transfer(msg.sender, amount);
  }
}
