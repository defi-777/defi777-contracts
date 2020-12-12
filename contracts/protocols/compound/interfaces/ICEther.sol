// SPDX-License-Identifier: MIT
pragma solidity ^0.6.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ICEther is IERC20 {
    function underlying() external view returns (address);

    function mint() external payable returns (uint _error);
    function redeem(uint redeemTokens) external returns (uint _error);
    // function redeemUnderlying(uint redeemAmount) external returns (uint _error);
    // function exchangeRateStored() external view returns (uint);
    // function exchangeRateCurrent() external returns (uint);
}
