pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../ILendingPool.sol";
import "./TestAaveLendingPoolCore.sol";

contract TestAaveLendingPool is ILendingPool {
  address private _core;

  constructor() public {
    _core = address(new TestAaveLendingPoolCore());
  }

  function core() external view override returns (ILendingPoolCore) {
    return ILendingPoolCore(_core);
  }

  function deposit(address _reserve, uint256 _amount, uint16 _referralCode) external payable override {
    TestAaveLendingPoolCore(_core).deposit{value: msg.value}(_reserve, _amount, msg.sender);
  }
}
