pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "../../Receiver.sol";
import "../../tokens/IWrapped777.sol";
import "./IPoolTogetherPool.sol";

contract PoolTogether777 is Receiver, Ownable {
  mapping(address => IPoolTogetherPool) private poolTokenToPool;
  mapping(address => IPoolTogetherPool) public tokenToPool;
  mapping(address => IWrapped777) private poolToWrapper;

  address private silentReceive;

  function addPool(IPoolTogetherPool pool, IWrapped777 wrapper) external onlyOwner {
    ERC20 token = pool.token();
    ERC777 poolToken = pool.poolToken();

    require(address(wrapper.token()) == address(token));

    poolTokenToPool[address(poolToken)] = pool;
    tokenToPool[address(token)] = pool;
    poolToWrapper[address(pool)] = wrapper;
  }

  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory /*data*/) internal override {
    if (address(_token) == silentReceive) {
      return;
    }

    IPoolTogetherPool pool = poolTokenToPool[address(_token)];
    if (address(pool) != address(0) /* token is a PoolToken */) {
      pool.withdraw(amount);
      IWrapped777 wrapper = poolToWrapper[address(pool)];

      pool.token().approve(address(wrapper), amount);
      silentReceive = address(wrapper);
      uint adjustedAmount = wrapper.wrap(amount);
      silentReceive = address(0);
      ERC20(address(wrapper)).transfer(from, adjustedAmount);
      return;
    }

    ERC20 wrappedToken = IWrapped777(address(_token)).token();
    pool = tokenToPool[address(wrappedToken)];
    if (address(pool) != address(0) /* token is Dai777/USDC777 */) {
      _token.send(address(_token), amount, '');
      uint256 adjustedAmount = wrappedToken.balanceOf(address(this));
      wrappedToken.approve(address(pool), adjustedAmount);

      ERC777 poolToken = pool.poolToken();
      silentReceive = address(poolToken);
      pool.depositPool(adjustedAmount);
      silentReceive = address(0);

      poolToken.transfer(from, adjustedAmount);
    } else {
      revert("Unsupported token");
    }
  }
}
