pragma solidity >=0.6.2 <0.7.0;

contract Granularity {
  uint256 internal _decimals;

  function setDecimals(uint decimals) internal {
    _decimals = decimals;
  }

  function getGranularity() internal view returns (uint256) {
    return 10 ** (18 - _decimals);
  }

  function from777to20(uint amount) internal view returns (uint256) {
    return amount / getGranularity();
  }

  function from20to777(uint amount) internal view returns (uint256) {
    return amount * getGranularity();
  }
}
