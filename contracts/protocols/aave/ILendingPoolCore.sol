pragma solidity >=0.6.2 <0.7.0;

interface ILendingPoolCore {
  function getReserveATokenAddress(address _reserve) external /*view*/ returns (address);
}
