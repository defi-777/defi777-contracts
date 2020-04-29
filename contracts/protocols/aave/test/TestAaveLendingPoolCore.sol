pragma solidity >=0.6.2 <0.7.0;

import "../ILendingPoolCore.sol";
import "./TestAToken.sol";

contract TestAaveLendingPoolCore is ILendingPoolCore {
  mapping(address => address) private aTokens;

  function getReserveATokenAddress(address _reserve) external /*view*/ override returns (address) {
    if (aTokens[_reserve] == address(0)) {
      aTokens[_reserve] = address(new TestAToken(_reserve));
    }

    return aTokens[_reserve];
  }

  function deposit(address _reserve, uint256 _amount, address user) external {
    TestAToken _token = TestAToken(aTokens[_reserve]);

    ERC20(_reserve).transferFrom(user, address(this), _amount);
    ERC20(_reserve).approve(address(_token), _amount);

    _token.deposit(_amount);
    _token.transfer(user, _amount);
  }
}
