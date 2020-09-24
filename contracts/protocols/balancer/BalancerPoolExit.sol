pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/introspection/IERC1820Registry.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../Receiver.sol";
import "../../InfiniteApprove.sol";
import "../../farming/IFarmerToken.sol";
import "../../tokens/IWrapperFactory.sol";
import "../../tokens/IWrapped777.sol";
import "./interfaces/BPool.sol";
import "./interfaces/IWETH.sol";
import "./IBalancerPoolFactory.sol";


contract BalancerPoolExit is Receiver, InfiniteApprove {
  IWrapped777 public immutable token;
  ERC20 public immutable innerToken;

  uint256 private constant INFINITY = uint256(-1);

  IERC1820Registry constant internal _ERC1820_REGISTRY = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

  constructor() public {
    IWrapped777 _token = IWrapped777(IWrapperFactory(msg.sender).nextToken());

    ERC20 _innerToken;
    if (address(_token) == address(0)) {
      _innerToken = ERC20(IBalancerPoolFactory(msg.sender).weth());
    } else {
      _innerToken = ERC20(_token.token());
      infiniteApprove(_innerToken, address(_token), 1);
    }

    token = _token;
    innerToken = _innerToken;
  }

  receive() external payable {}

  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory /*data*/) internal override {
    IWrapped777 inputWrapper = IWrapped777(address(_token));
    BPool pool = BPool(address(inputWrapper.token()));

    address implementer = _ERC1820_REGISTRY.getInterfaceImplementer(address(_token), keccak256("Farmer777"));
    if (implementer != address(0) /* token is FarmerToken */) {
      farmRewards(IFarmerToken(address(_token)), from);
    }

    uint256 poolTokens = inputWrapper.unwrap(amount);

    uint256 exitAmount = pool.exitswapPoolAmountIn(address(innerToken), poolTokens, 0);

    if (address(token) == address(0)) {
      IWETH(address(innerToken)).withdraw(exitAmount);
      (bool success,) = payable(from).call{value: exitAmount}("");
      require(success);
    } else {
      infiniteApprove(innerToken, address(token), exitAmount);
      token.wrapTo(exitAmount, from);
    }
  }

  function farmRewards(IFarmerToken _token, address recipient) private {
    address[] memory rewardTokens = _token.rewardTokens();
    for (uint i = 0; i < rewardTokens.length; i++) {
      ERC20 rewardAdapter = ERC20(_token.getRewardAdapter(rewardTokens[i]));
      uint256 rewardBalance = rewardAdapter.balanceOf(address(this));
      if (rewardBalance > 0) {
        rewardAdapter.transfer(recipient, rewardBalance);
      }
    }
  }
}
