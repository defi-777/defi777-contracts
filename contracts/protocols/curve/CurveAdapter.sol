// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../tokens/IWrapped777.sol";
import "../../Receiver.sol";
import "./interfaces/ICurvePool.sol";

contract CurveAdapter is Receiver {
  mapping(address => int128) private tokenID;

  IWrapped777 public immutable wrapper;
  ICurvePool public immutable pool;
  int128 private immutable numTokens;

  uint256 private constant INFINITY = uint256(-1);

  constructor(IWrapped777 _wrapper, int128 _numTokens) public {
    ICurvePool _pool = ICurvePool(address(_wrapper.token()));
    wrapper = _wrapper;
    numTokens = _numTokens;
    pool = _pool;

    for (int128 i; i < _numTokens; i++) {
      tokenID[_pool.coins(i)] = i + 1;
    }

    infiniteApprove(ERC20(address(_pool)), address(_wrapper), 1);
  }

  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory /*data*/) internal override {
    IWrapped777 inputWrapper = IWrapped777(address(_token));
    ERC20 wrappedToken = inputWrapper.token();

    int128 id = tokenID[address(wrappedToken)];
    if (id == 0) {
      revert('Unsupported');
    }
    id--;

    uint256 unwrappedAmount = inputWrapper.unwrap(amount);
    infiniteApprove(wrappedToken, address(pool), unwrappedAmount);

    addLiquidity(id, unwrappedAmount);

    uint256 newTokens = ERC20(address(pool)).balanceOf(address(this));
    wrapper.wrapTo(newTokens, from);
  }

  function addLiquidity(int128 id, uint256 amount) private {
    if (numTokens == 4) {
      uint256[4] memory fourTokens;
      fourTokens[uint256(id)] = amount;
      pool.add_liquidity(fourTokens, 0);
    } else if (numTokens == 3) {
      uint256[3] memory threeTokens;
      threeTokens[uint256(id)] = amount;
      pool.add_liquidity(threeTokens, 0);
    } else if (numTokens == 2) {
      uint256[2] memory twoTokens;
      twoTokens[uint256(id)] = amount;
      pool.add_liquidity(twoTokens, 0);
    } else {
      revert();
    }
  }

  function infiniteApprove(ERC20 _token, address spender, uint256 amount) private {
    if (_token.allowance(address(this), spender) < amount) {
      _token.approve(spender, INFINITY);
    }
  }
}
