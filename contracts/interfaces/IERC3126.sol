// SPDX-License-Identifier: MIT
pragma solidity ^0.6.2;

/// @title Defines a standard interface for viewing the addresses and balances of underlying tokens.
interface IERC3126 {
  /// @notice Should return a list of addresses for tokens that may be custodied by this contract
  /// @return The list of token addresses.
  function underlyingTokens() external view returns (address[] memory);

  /// @notice Returns the underlying amount of a token that a user holds
  /// @param user The user whose underlying balance should be calculated
  /// @param token The token whose balance we want.
  /// @return The underlying balance of the given token for the user.
  function balanceOfUnderlying(address user, address token) external view returns (uint256);
}
