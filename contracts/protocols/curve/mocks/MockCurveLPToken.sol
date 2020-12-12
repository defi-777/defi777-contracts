// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockCurveLPToken is ERC20("y Curve Pool", "yCRV") {
  function mint(address user, uint256 amount) external {
    _mint(user, amount);
  }

  function burn(address user, uint256 amount) external {
    _burn(user, amount);
  }
}
