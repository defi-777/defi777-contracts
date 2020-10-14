// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IyVault is IERC20 {
  function token() external view returns (address);
  function deposit(uint _amount) external;
  function withdraw(uint _shares) external;
}
