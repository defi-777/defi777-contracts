pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract InfiniteApprove {
  uint256 internal constant INFINITY = uint256(-1);

  function infiniteApprove(ERC20 _token, address spender, uint256 amount) internal {
    if (_token.allowance(address(this), spender) < amount) {
      _token.approve(spender, INFINITY);
    }
  }
}
