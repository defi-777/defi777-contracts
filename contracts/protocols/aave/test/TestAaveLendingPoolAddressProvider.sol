pragma solidity >=0.6.2 <0.7.0;

import "../ILendingPool.sol";
import "../ILendingPoolAddressesProvider.sol";
import "./TestAaveLendingPool.sol";

contract TestAaveLendingPoolAddressProvider is ILendingPoolAddressesProvider {
  address private lendingPool;

  constructor() public {
    lendingPool = address(new TestAaveLendingPool());
  }

  function getLendingPool() external view override returns (ILendingPool) {
    return ILendingPool(lendingPool);
  }
}
