pragma solidity >=0.6.2 <0.7.0;

interface IPermit {
  // ERC-2612 permit
  function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;

  // Dai Permit
  function permit(address holder, address spender, uint256 nonce, uint256 expiry,
                  bool allowed, uint8 v, bytes32 r, bytes32 s) external;
}