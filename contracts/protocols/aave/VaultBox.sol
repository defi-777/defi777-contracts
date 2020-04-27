pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VaultBox {
  address private vault;

  constructor() public {
    vault = msg.sender;
  }

  function remove(address token, uint256 amount) external {
    IERC20(token).transfer(msg.sender, amount);
  }
}
