pragma solidity >=0.6.2 <0.7.0;

import "../IAToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestAToken is IAToken, ERC20 {
  address private _reserve;
  constructor(address reserve) public ERC20("TestA", "aTST") {
    _reserve = reserve;
  }

  function deposit(uint256 _amount) external {
    ERC20(_reserve).transferFrom(msg.sender, address(this), _amount);
    _mint(msg.sender, _amount);
  }

  function redeem(uint256 _amount) external override {
    _burn(msg.sender, _amount);
    ERC20(_reserve).transfer(msg.sender, _amount);
  }
}
