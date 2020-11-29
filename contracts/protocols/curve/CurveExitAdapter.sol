// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/introspection/IERC1820Registry.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../farming/IFarmerToken.sol";
import "../../tokens/IWrapperFactory.sol";
import "../../tokens/IWrapped777.sol";
import "../../ReverseENS.sol";
import "../../Receiver.sol";
import "./interfaces/ICurvePool.sol";


contract CurveExitAdapter is Receiver, ReverseENS {
  IWrapped777 public immutable token;
  ERC20 public immutable innerToken;

  uint256 private constant INFINITY = uint256(-1);

  IERC1820Registry constant internal _ERC1820_REGISTRY = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

  constructor(IWrapped777 _wrapper) public {
    token = _wrapper;
    innerToken = _wrapper.token();
  }

  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory /*data*/) internal override {
    IWrapped777 inputWrapper = IWrapped777(address(_token));
    ICurvePool pool = ICurvePool(address(inputWrapper.token()));

    address implementer = _ERC1820_REGISTRY.getInterfaceImplementer(address(_token), keccak256("Farmer777"));
    if (implementer != address(0) /* token is FarmerToken */) {
      farmRewards(IFarmerToken(address(_token)), from);
    }

    uint256 poolTokens = inputWrapper.unwrap(amount);

    int128 id = 0;
    for (; id < 5; id++) {
      if (pool.coins(id) == address(innerToken)) {
        break;
      }
    }

    removeLiquidity(pool, id, poolTokens);

    innerToken.transfer(address(token), innerToken.balanceOf(address(this)));
    token.gulp(from);
  }

  function farmRewards(IFarmerToken _token, address recipient) private {
    address[] memory rewardWrappers = _token.rewardWrappers();
    for (uint i = 0; i < rewardWrappers.length; i++) {
      ERC20 rewardAdapter = ERC20(_token.getRewardAdapter(rewardWrappers[i]));
      rewardAdapter.transfer(recipient, rewardAdapter.balanceOf(address(this)));
    }
  }

  function removeLiquidity(ICurvePool pool, int128 id, uint256 amount) private {
    uint256[4] memory fourTokens;
    fourTokens[uint256(id)] = amount;
    try pool.remove_liquidity_imbalance(fourTokens, 0) {} catch {
      uint256[3] memory threeTokens;
      threeTokens[uint256(id)] = amount;
      try pool.remove_liquidity_imbalance(threeTokens, 0) {} catch {
        uint256[2] memory twoTokens;
        twoTokens[uint256(id)] = amount;
        pool.remove_liquidity_imbalance(twoTokens, 0);
      }
    }
  }
}
