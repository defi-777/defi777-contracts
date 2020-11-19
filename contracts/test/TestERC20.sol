pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20 {
  constructor() public ERC20("Test", "TST") {
    _mint(msg.sender, 10000 ether);
  }
}
