pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestUSDC is ERC20 {
  constructor() public ERC20("USDC", "USDC") {
    _mint(msg.sender, 100 * 1000000);
    _setupDecimals(6);
  }
}
