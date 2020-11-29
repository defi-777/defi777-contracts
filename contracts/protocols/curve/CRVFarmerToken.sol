// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../farming/FarmerToken.sol";
import "../../Receiver.sol";
import "../../InfiniteApprove.sol";
import "./interfaces/ICurveGague.sol";
import "./interfaces/ICurveMinter.sol";
import "./ICRVFarmerFactory.sol";

contract CRVFarmerToken is FarmerToken, InfiniteApprove {
  ICurveGague private immutable gague;

  constructor() public {
    gague = ICurveGague(ICRVFarmerFactory(msg.sender).nextGague());
  }

  function preMint(uint256 amount) internal override {
    infiniteApprove(token, address(gague), amount);
    gague.deposit(amount);
  }

  function preBurn(uint256 amount) internal override {
    gague.withdraw(amount);
  }

  function farm(ICurveMinter minter) external {
    minter.mint(address(gague));
    harvest(minter.token());
  }
}
