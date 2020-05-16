pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";

contract TestPoolToken {
  using Address for address;

  mapping(address => uint256) public balanceOf;

  function transfer(address recipient, uint256 amount) external returns (bool) {
    require(balanceOf[msg.sender] >= amount, 'PoolToken: insufficent balance');
    balanceOf[msg.sender] -= amount;
    balanceOf[recipient] += amount;

    if (recipient.isContract()) {
      IERC777Recipient(recipient).tokensReceived(address(0), msg.sender, recipient, amount, '', '');
    }
    return true;
  }

  function mint(address recipient, uint256 amount) external {
    balanceOf[recipient] += amount;

    if (recipient.isContract()) {
      IERC777Recipient(recipient).tokensReceived(address(0), address(0), recipient, amount, '', '');
    }
  }

  function burn(address holder, uint256 amount) external {
    require(balanceOf[holder] >= amount);
    balanceOf[holder] -= amount;
  }
}
