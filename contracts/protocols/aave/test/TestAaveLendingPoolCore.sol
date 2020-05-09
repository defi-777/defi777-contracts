pragma solidity >=0.6.2 <0.7.0;

import "../ILendingPoolCore.sol";
import "./TestAToken.sol";

contract TestAaveLendingPoolCore is ILendingPoolCore {
  mapping(address => address) private aTokens;

  address constant private ETH_FAKE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  function getReserveATokenAddress(address _reserve) external /*view*/ override returns (address) {
    if (aTokens[_reserve] == address(0)) {
      aTokens[_reserve] = address(new TestAToken(_reserve));
    }

    return aTokens[_reserve];
  }

  function deposit(address _reserve, uint256 _amount, address user) external payable {
    TestAToken _token = TestAToken(aTokens[_reserve]);

    if (_reserve == ETH_FAKE_TOKEN) {
      require(msg.value == _amount);
    } else {
      ERC20(_reserve).transferFrom(user, address(this), _amount);
      ERC20(_reserve).approve(address(_token), _amount);
    }

    _token.deposit{value: msg.value}(_amount);
    _token.transfer(user, _amount);
  }
}
