// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ICurveGague.sol";

contract TestCurveGague is ICurveGague {
  address public poolToken;

  mapping(address => uint256) public balance;

  constructor(address _poolToken) public {
    poolToken = _poolToken;
  }

  function deposit(uint256 amount) external override {
    balance[msg.sender] += amount;
    IERC20(poolToken).transferFrom(msg.sender, address(this), amount);
  }

  function withdraw(uint256 amount) external override {
    balance[msg.sender] -= amount;
    IERC20(poolToken).transfer(msg.sender, amount);
  }
}
