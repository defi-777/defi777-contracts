// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

interface IReverseRegistrar {
  function claim(address owner) external returns (bytes32);
}

contract ReverseENS {
  constructor() internal {
    bytes memory callData = abi.encodeWithSelector(IReverseRegistrar.claim.selector, tx.origin);
    (bool success,) = 0x084b1c3C81545d370f3634392De611CaaBFf8148.call(callData);

    if (!success) {
      (success,) = 0x6F628b68b30Dc3c17f345c9dbBb1E483c2b7aE5c.call(callData);
    }
  }
}
