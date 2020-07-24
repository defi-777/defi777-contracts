pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/ISynth.sol";

contract TestSynth is ERC20, ISynth {
  constructor(string memory symbol) public ERC20(symbol, symbol) {}

  function issue(address recipient, uint256 amount) external override {
    _mint(recipient, amount);
  }

  function burn(address owner, uint256 amount) external override {
    _burn(owner, amount);
  }
}
