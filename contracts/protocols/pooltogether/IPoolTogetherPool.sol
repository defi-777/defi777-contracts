pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IPoolTogetherPool {
  function poolToken() external view returns (ERC777);
  function token() external view returns (ERC20);

  function depositPool(uint256 _amount) external;
  function withdraw(uint256 amount) external;
}
