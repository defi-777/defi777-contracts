// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./TestAToken.sol";

contract TestAaveLendingPool {
  mapping(address => address) public getAToken;

  function createAToken(address token) external {
    getAToken[token] = address(new TestAToken());
  }

  function deposit(
    address reserve,
    uint256 amount,
    address onBehalfOf,
    uint16 /*referralCode*/
  ) external {
    IERC20(reserve).transferFrom(msg.sender, address(this), amount);
    TestAToken(getAToken[reserve]).mint(onBehalfOf, amount);
  }

  function withdraw(
    address reserve,
    uint256 amount,
    address to
  ) external {
    TestAToken(getAToken[reserve]).burn(msg.sender, amount);
    IERC20(reserve).transfer(to, amount);
  }
}
