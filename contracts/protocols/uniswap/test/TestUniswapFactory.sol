// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "../interfaces/IUniswapV2Factory.sol";
import "./TestUniswapPair.sol";

contract TestUniswapFactory is IUniswapV2Factory {

  mapping(address => mapping(address => address)) private pairs;

  function getPair(address tokenA, address tokenB) external override view returns (address pair) {
    return pairs[tokenA][tokenB];
  }

  function createPair(address tokenA, address tokenB) external override returns (address pair) {
    (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    require(pairs[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS'); // single check is sufficient

    pair = address(new TestUniswapPair{ salt: keccak256(abi.encodePacked(token0, token1)) }(token0, token1));

    pairs[token0][token1] = pair;
    pairs[token1][token0] = pair; // populate mapping in the reverse direction
  }
}
