pragma solidity >=0.6.2 <0.7.0;

import "./ILendingPoolCore.sol";

interface ILendingPool {
  function core() external view returns (ILendingPoolCore);

  function deposit(address _reserve, uint256 _amount, uint16 _referralCode) external payable;
}
