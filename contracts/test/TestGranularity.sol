pragma solidity >=0.6.2 <0.7.0;

import "../tokens/Granularity.sol";

contract TestGranularity is Granularity {
  constructor(uint decimals) public {
    setDecimals(decimals);
  }

  function granularity() external view returns (uint256) {
    return Granularity.getGranularity();
  }

  function test777to20(uint amount) external view returns (uint256) {
    return Granularity.from777to20(amount);
  }

  function test20to777(uint amount) external view returns (uint256) {
    return Granularity.from20to777(amount);
  }
}
