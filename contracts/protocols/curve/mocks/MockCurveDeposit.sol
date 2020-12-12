// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/ICurveDeposit.sol";
import "./MockCurveLPToken.sol";

contract MockCurveDeposit is ICurveDeposit, ERC20 {
  address[] private tokens;

  address public override token;

  constructor(address[3] memory _tokens) public ERC20("y Curve Pool", "yCRV") {
    tokens = _tokens;
    token = address(new MockCurveLPToken());
  }

  function coins(int128 i) external override view returns (address) {
    return tokens[uint256(i)];
  }

  function underlying_coins(int128) external override view returns (address) {
    revert('Unsupported');
  }

  function add_liquidity(
    uint256[3] calldata amounts,
    uint256 /*min_mint_amount*/
  ) external override {
    uint mintAmt = 0;
    for (uint i = 0; i < 3; i++) {
      if (amounts[i] != 0) {
        ERC20(tokens[uint256(i)]).transferFrom(msg.sender, address(this), amounts[uint256(i)]);
        mintAmt += amounts[uint256(i)];
      }
    }
    MockCurveLPToken(token).mint(msg.sender, mintAmt);
  }

  function add_liquidity(
    uint256[2] calldata /*amounts*/,
    uint256 /*min_mint_amount*/
  ) external override {
    revert('Unsupported');
  }

  function add_liquidity(
    uint256[4] calldata /*amounts*/,
    uint256 /*min_mint_amount*/
  ) external override {
    revert('Unsupported');
  }

  function remove_liquidity_imbalance(
    uint256[3] calldata amounts,
    uint256 /*max_burn_amount*/
  ) external override {
    uint burnAmt = 0;
    for (uint i = 0; i < 3; i++) {
      if (amounts[i] != 0) {
        ERC20(tokens[uint256(i)]).transfer(msg.sender, amounts[uint256(i)]);
        burnAmt += amounts[uint256(i)];
      }
    }

    MockCurveLPToken(token).burn(msg.sender, burnAmt);
  }

  function remove_liquidity_imbalance(
    uint256[2] calldata /*amounts*/,
    uint256 /*max_burn_amount*/
  ) external override {
    revert('Unsupported');
  }

  function remove_liquidity_imbalance(
    uint256[4] calldata /*amounts*/,
    uint256 /*max_burn_amount*/
  ) external override {
    revert('Unsupported');
  }
}
