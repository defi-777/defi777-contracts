// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/introspection/IERC1820Registry.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "../../ens/ReverseENS.sol";
import "../../farming/IFarmerToken.sol";
import "../../interfaces/IWETH.sol";
import "../../tokens/IWrapped777.sol";
import "../../Receiver.sol";
import "./interfaces/BPool.sol";

contract BalancerPoolETHExitAdapter is Receiver, ReverseENS {
  using SafeMath for uint256;

  IWETH public immutable weth;

  IERC1820Registry constant internal _ERC1820_REGISTRY = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

  constructor(IWETH _weth) public {
    weth = _weth;
  }

  receive() external payable {
    require(msg.sender == address(weth));
  }

  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory /*data*/) internal override {
    IWrapped777 inputWrapper = IWrapped777(address(_token));
    BPool pool = BPool(address(inputWrapper.token()));

    address implementer = _ERC1820_REGISTRY.getInterfaceImplementer(address(_token), keccak256("Farmer777"));
    if (implementer != address(0) /* token is FarmerToken */) {
      farmRewards(IFarmerToken(address(_token)), from);
    }

    uint256 poolTokens = inputWrapper.unwrap(amount);

    uint256 exitAmount = pool.exitswapPoolAmountIn(address(weth), poolTokens, 0);

    weth.withdraw(exitAmount);
    TransferHelper.safeTransferETH(from, exitAmount);
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
