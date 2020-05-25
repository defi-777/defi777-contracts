pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./IWrapped777.sol";
import "../Receiver.sol";

contract Unwrapper is Receiver {
  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory /*data*/) internal override {
    _token.send(address(_token), amount, '');

    ERC20 innerToken = IWrapped777(address(_token)).token();
    uint256 decimals = innerToken.decimals();

    uint256 resultBalance = innerToken.balanceOf(address(this));
    require(resultBalance >= from777to20(amount, decimals), "Token didn't unwrap");

    innerToken.transfer(from, resultBalance);
  }

  function from777to20(uint amount, uint256 decimals) private pure returns (uint256) {
    uint256 granularity = 10 ** (18 - decimals);
    return amount / granularity;
  }
}
