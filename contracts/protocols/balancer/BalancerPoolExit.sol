pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../Receiver.sol";
import "../../tokens/IWrapperFactory.sol";
import "../../tokens/IWrapped777.sol";
import "./interfaces/BPool.sol";
import "./interfaces/IWETH.sol";
import "./IBalancerPoolFactory.sol";

contract BalancerPoolExit is Receiver {
  IWrapped777 public immutable token;
  ERC20 public immutable innerToken;

  uint256 private constant INFINITY = uint256(-1);

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

  receive() external payable {
    // Only allow eth sent from WETH
    require(msg.sender == address(innerToken));
  }

  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory /*data*/) internal override {
    IWrapped777 inputWrapper = IWrapped777(address(_token));
    BPool pool = BPool(address(inputWrapper.token()));

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

  function infiniteApprove(ERC20 _token, address spender, uint256 amount) private {
    if (_token.allowance(address(this), spender) < amount) {
      _token.approve(spender, INFINITY);
    }
  }
}
