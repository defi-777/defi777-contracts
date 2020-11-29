// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/introspection/IERC1820Registry.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "../../farming/IFarmerToken.sol";
import "../../tokens/IWrapperFactory.sol";
import "../../tokens/IWrapped777.sol";
import "../../interfaces/IWETH.sol";
import "../../Receiver.sol";
import "../../ReverseENS.sol";
import "./interfaces/BPool.sol";


contract BalancerPoolExit is Receiver, ReverseENS {
  IWrapped777 public immutable token;
  ERC20 public immutable innerToken;

  IERC1820Registry constant internal _ERC1820_REGISTRY = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

  constructor() public {
    IWrapped777 _token = IWrapped777(IWrapperFactory(msg.sender).nextToken());

    innerToken = ERC20(_token.token());
    token = _token;
  }

  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory /*data*/) internal override {
    IWrapped777 inputWrapper = IWrapped777(address(_token));
    BPool pool = BPool(address(inputWrapper.token()));

    address implementer = _ERC1820_REGISTRY.getInterfaceImplementer(address(_token), keccak256("Farmer777"));
    if (implementer != address(0) /* token is FarmerToken */) {
      farmRewards(IFarmerToken(address(_token)), from);
    }

    uint256 poolTokens = inputWrapper.unwrap(amount);

    uint256 exitAmount = pool.exitswapPoolAmountIn(address(innerToken), poolTokens, 0);

    innerToken.transfer(address(token), exitAmount);
    token.gulp(from);
  }

  function farmRewards(IFarmerToken _token, address recipient) private {
    address[] memory rewardWrappers = _token.rewardWrappers();

    for (uint i = 0; i < rewardWrappers.length; i++) {
      ERC20 rewardAdapter = ERC20(_token.getRewardAdapter(rewardWrappers[i]));
      uint256 rewardBalance = rewardAdapter.balanceOf(address(this));
      if (rewardBalance > 0) {
        rewardAdapter.transfer(recipient, rewardBalance);
      }
    }
  }
}
