pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../Receiver.sol";
import "../../tokens/IWrapperFactory.sol";
import "../../tokens/IWrapped777.sol";
import "./interfaces/BPool.sol";
import "./interfaces/IWETH.sol";
import "./IBalancerPoolFactory.sol";

contract BalancerPool is Receiver {
  IWrapped777 public immutable token;
  BPool public immutable pool;
  IWETH private immutable weth;

  address private wrapping;

  uint256 private constant INFINITY = uint256(-1);

  constructor() public {
    IWrapped777 _token = IWrapped777(IWrapperFactory(msg.sender).nextToken());
    weth = IWETH(IBalancerPoolFactory(msg.sender).weth());
    BPool _pool = BPool(address(_token.token()));
    token = _token;
    pool = _pool;

    infiniteApprove(ERC20(address(_pool)), address(_token), 1);
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
    infiniteApprove(tokenIn, address(pool), amount);
    uint256 poolTokens = pool.joinswapExternAmountIn(address(tokenIn), amount, 0);
    
    infiniteApprove(ERC20(address(pool)), address(token), poolTokens);
    token.wrapTo(poolTokens, recipient);
  }

  function infiniteApprove(ERC20 _token, address spender, uint256 amount) private {
    if (_token.allowance(address(this), spender) < amount) {
      _token.approve(spender, INFINITY);
    }
  }
}
