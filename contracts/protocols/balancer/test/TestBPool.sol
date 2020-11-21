// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/BPool.sol";

contract TestBPool is BPool, ERC20 {
  address[] private tokens;
  mapping(address => bool) private hasToken;

  constructor(address[] memory _tokens) public ERC20("Balancer Pool Token", "BPT") {
    tokens = _tokens;
    for (uint i = 0; i < _tokens.length; i++) {
      hasToken[_tokens[i]] = true;
    }
  }

  function getCurrentTokens() external view override returns (address[] memory) {
    return tokens;
  }

  function swapExactAmountIn(
    address tokenIn,
    uint tokenAmountIn,
    address tokenOut,
    uint /*minAmountOut*/,
    uint /*maxPrice*/
  ) external override returns (uint tokenAmountOut, uint spotPriceAfter) {
    require(hasToken[tokenIn] && hasToken[tokenOut], 'Unsupported token');
    ERC20(tokenIn).transferFrom(msg.sender, address(this), tokenAmountIn);
    ERC20(tokenOut).transfer(msg.sender, tokenAmountIn);
    return (tokenAmountIn, 1);
  }

  function getSpotPrice(address /*tokenIn*/, address /*tokenOut*/) external view override returns (uint spotPrice) {
    this;
    return 1;
  }

  function joinswapExternAmountIn(
    address tokenIn,
    uint tokenAmountIn,
    uint /*minPoolAmountOut*/
  ) external override returns (uint poolAmountOut) {
    require(hasToken[tokenIn]);
    ERC20(tokenIn).transferFrom(msg.sender, address(this), tokenAmountIn);
    _mint(msg.sender, tokenAmountIn);
    poolAmountOut = tokenAmountIn;
  }

  function exitswapPoolAmountIn(
    address tokenOut,
    uint poolAmountIn,
    uint /*minAmountOut*/
  ) external override returns (uint tokenAmountOut) {
    require(hasToken[tokenOut]);
    _burn(msg.sender, poolAmountIn);
    ERC20(tokenOut).transfer(msg.sender, poolAmountIn);
    tokenAmountOut = poolAmountIn;
  }
}
