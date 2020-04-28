pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../protocols/aave/Vault.sol";

contract TestVault is Vault {
  function testBalanceOf(ERC20 token, address user) external view returns (uint256) {
    return Vault.vaultBalance(token, user);
  }

  function testDeposit(ERC20 token, address user) external {
    Vault.deposit(token, user);
  }

  function testTransfer(ERC20 token, address from, address to, uint256 amount) external {
    Vault.transfer(token, from, to, amount);
  }

  function testWithdraw(ERC20 token, address from, uint256 amount) external {
    Vault.withdraw(token, from, amount);
  }
}
