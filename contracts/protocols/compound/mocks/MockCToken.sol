// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockCToken is ERC20("Compound Token", "cTKN") {
  ERC20 public immutable underlying;

  constructor(ERC20 _underlying) public {
    underlying = _underlying;
  }

  function mint(uint256 amount) external returns (uint) {
    underlying.transferFrom(msg.sender, address(this), amount);
    _mint(msg.sender, amount);
  }

  function redeem(uint256 amount) external returns (uint) {
    underlying.transfer(msg.sender, amount);
    _burn(msg.sender, amount);
  }
}
