pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestBPool {
  address[] private tokens;
  mapping(address => bool) private hasToken;

  constructor(address[] memory _tokens) public {
    tokens = _tokens;
    for (uint i = 0; i < _tokens.length; i++) {
      hasToken[_tokens[i]] = true;
    }
  }

  function getCurrentTokens() external view returns (address[] memory) {
    return tokens;
  }

  function swapExactAmountIn(
    address tokenIn,
    uint tokenAmountIn,
    address tokenOut,
    uint /*minAmountOut*/,
    uint /*maxPrice*/
  ) external returns (uint tokenAmountOut, uint spotPriceAfter) {
    require(hasToken[tokenIn] && hasToken[tokenOut], 'Unsupported token');
    ERC20(tokenIn).transferFrom(msg.sender, address(this), tokenAmountIn);
    ERC20(tokenOut).transfer(msg.sender, tokenAmountIn);
    return (tokenAmountIn, 1);
  }

  function getSpotPrice(address /*tokenIn*/, address /*tokenOut*/) external pure returns (uint spotPrice) {
    return 1;
  }
}
