// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

interface IReverseRegistrar {
  function claim(address owner) external returns (bytes32);
}

contract ReverseENS {
  constructor() internal {
    try IReverseRegistrar(0x084b1c3C81545d370f3634392De611CaaBFf8148).claim(tx.origin) {} catch {}
  }
}
