// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/introspection/IERC1820Registry.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../ens/ReverseENS.sol";
import "../../farming/IFarmerToken.sol";
import "../../tokens/IWrapperFactory.sol";
import "../../tokens/IWrapped777.sol";
import "../../Receiver.sol";
import "./interfaces/ICurveDeposit.sol";
import "./CurveRegistry.sol";


contract CurveExitAdapter is Receiver, ReverseENS {
  IWrapped777 public immutable wrapper;
  ERC20 public immutable innerToken;
  CurveRegistry public immutable registry;

  IERC1820Registry constant internal _ERC1820_REGISTRY = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

  constructor(IWrapped777 _wrapper, CurveRegistry _registry) public {
    wrapper = _wrapper;
    innerToken = _wrapper.token();
    registry = _registry;
    _registry.registerAdapter(true);
  }

  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory /*data*/) internal override {
    IWrapped777 inputWrapper = IWrapped777(address(_token));
    ERC20 lpToken = inputWrapper.token();

    address implementer = _ERC1820_REGISTRY.getInterfaceImplementer(address(_token), keccak256("Farmer777"));
    if (implementer != address(0) /* token is FarmerToken */) {
      farmRewards(IFarmerToken(address(_token)), from);
    }

    uint256 lpTokens = inputWrapper.unwrap(amount);

    (address depositor, uint8 numTokens, int128 index) = registry.getDepositor(address(lpToken), address(innerToken));

    removeLiquidity(ICurveDeposit(depositor), index, numTokens, lpTokens);

    innerToken.transfer(address(wrapper), innerToken.balanceOf(address(this)));
    wrapper.gulp(from);
  }

  function farmRewards(IFarmerToken _token, address recipient) private {
    address[] memory rewardWrappers = _token.rewardWrappers();
    for (uint i = 0; i < rewardWrappers.length; i++) {
      ERC20 rewardAdapter = ERC20(_token.getRewardAdapter(rewardWrappers[i]));
      rewardAdapter.transfer(recipient, rewardAdapter.balanceOf(address(this)));
    }
  }

  function removeLiquidity(ICurveDeposit depositor, int128 index, uint256 numTokens, uint256 amount) private {
    if (numTokens == 4) {
      uint256[4] memory fourTokens;
      fourTokens[uint256(index)] = amount;
      depositor.remove_liquidity_imbalance(fourTokens, 0);
    } else if (numTokens == 3) {
      uint256[3] memory threeTokens;
      threeTokens[uint256(index)] = amount;
      depositor.remove_liquidity_imbalance(threeTokens, 0);
    } else if (numTokens == 2) {
      uint256[2] memory twoTokens;
      twoTokens[uint256(index)] = amount;
      depositor.remove_liquidity_imbalance(twoTokens, 0);
    } else {
      revert('TKNM');
    }
  }
}
