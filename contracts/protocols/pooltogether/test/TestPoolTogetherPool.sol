pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../IPoolTogetherPool.sol";
import "./TestPoolToken.sol";

contract TestPoolTogetherPool {
  ERC777 public poolToken;
  ERC20 public token;

  constructor(ERC20 _token) public {
    token = _token;
    poolToken = ERC777(address(new TestPoolToken()));
  }

  function depositPool(uint256 _amount) external {
    token.transferFrom(msg.sender, address(this), _amount);
    TestPoolToken(address(poolToken)).mint(msg.sender, _amount);
  }

  function withdraw(uint256 amount) external {
    TestPoolToken(address(poolToken)).burn(msg.sender, amount);
    token.transfer(msg.sender, amount);
  }
}
