// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "./TestAaveLendingPool.sol";

contract TestAaveLendingPoolAddressProvider {
  address private lendingPool;

  constructor() public {
    lendingPool = address(new TestAaveLendingPool());
  }

  function getLendingPool() external view returns (address) {
    return lendingPool;
  }
}
