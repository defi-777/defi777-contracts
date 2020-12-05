// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../ens/ReverseENS.sol";
import "../../tokens/IWrapperFactory.sol";
import "../../tokens/IWrapped777.sol";
import "../../interfaces/IWETH.sol";
import "../../Receiver.sol";
import "./interfaces/BPool.sol";
import "./IBalancerPoolFactory.sol";

contract BalancerPool is Receiver, ReverseENS {
  IWrapped777 public immutable token;
  BPool public immutable pool;
  IWETH private immutable weth;

  constructor() public {
    IWrapped777 _token = IWrapped777(IWrapperFactory(msg.sender).nextToken());
    weth = IWETH(IBalancerPoolFactory(msg.sender).weth());
    BPool _pool = BPool(address(_token.token()));
    token = _token;
    pool = _pool;
  }

  receive() external payable {
    weth.deposit{value: msg.value}();

    swapInToPool(ERC20(address(weth)), msg.value, msg.sender);
  }

  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory /*data*/) internal override {
    uint256 unwrappedAmount = IWrapped777(address(_token)).unwrap(amount);

    ERC20 innerInputToken = IWrapped777(address(_token)).token();

    swapInToPool(innerInputToken, unwrappedAmount, from);
  }

  function swapInToPool(ERC20 tokenIn, uint256 amount, address recipient) private {
    tokenIn.approve(address(pool), amount);
    uint256 poolTokens = pool.joinswapExternAmountIn(address(tokenIn), amount, 0);
    
    ERC20(address(pool)).transfer(address(token), poolTokens);
    token.gulp(recipient);
  }
}
