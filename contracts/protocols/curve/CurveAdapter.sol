// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../ens/ReverseENS.sol";
import "../../tokens/IWrapped777.sol";
import "../../Receiver.sol";
import "./interfaces/ICurveDeposit.sol";
import "./CurveRegistry.sol";

contract CurveAdapter is Receiver, ReverseENS {
  IWrapped777 public immutable wrapper;
  ERC20 public immutable lpToken;
  CurveRegistry public immutable registry;

  constructor(IWrapped777 _wrapper, CurveRegistry _registry) public {
    lpToken = _wrapper.token();
    wrapper = _wrapper;
    registry = _registry;
    _registry.registerAdapter(false);
  }

  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory /*data*/) internal override {
    IWrapped777 inputWrapper = IWrapped777(address(_token));
    ERC20 wrappedToken = inputWrapper.token();

    (address depositor, uint8 numTokens, int128 index) = registry.getDepositor(address(lpToken), address(wrappedToken));

    uint256 unwrappedAmount = inputWrapper.unwrap(amount);

    wrappedToken.approve(address(depositor), unwrappedAmount);
    addLiquidity(depositor, index, unwrappedAmount, numTokens);

    uint256 newTokens = lpToken.balanceOf(address(this));
    lpToken.transfer(address(wrapper), newTokens);
    wrapper.gulp(from);
  }

  function addLiquidity(address _depositor, int128 id, uint256 amount, uint8 numTokens) private {
    ICurveDeposit depositor = ICurveDeposit(_depositor);
    if (numTokens == 4) {
      uint256[4] memory fourTokens;
      fourTokens[uint256(id)] = amount;
      depositor.add_liquidity(fourTokens, 0);
    } else if (numTokens == 3) {
      uint256[3] memory threeTokens;
      threeTokens[uint256(id)] = amount;
      depositor.add_liquidity(threeTokens, 0);
    } else if (numTokens == 2) {
      uint256[2] memory twoTokens;
      twoTokens[uint256(id)] = amount;
      depositor.add_liquidity(twoTokens, 0);
    } else {
      revert();
    }
  }
}
