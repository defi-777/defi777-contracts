// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";

contract MockCEther is ERC20("Compound Ether", "cETH") {
  function mint() external payable returns (uint) {
    _mint(msg.sender, msg.value);
  }

  function redeem(uint256 amount) external returns (uint) {
    _burn(msg.sender, amount);
    TransferHelper.safeTransferETH(msg.sender, amount);
  }
}
