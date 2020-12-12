// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "../../../test/TestERC20.sol";
import "../interfaces/ICurveMinter.sol";
import "./TestCurveGague.sol";

contract TestCurveMinter is ICurveMinter {
  TestERC20 private _token;

  constructor() public {
    _token = new TestERC20();
  }

  function mint(address gague) external override {
    _token.transfer(msg.sender, TestCurveGague(gague).balance(msg.sender));
  }

  function token() external override view returns (address) {
    return address(_token);
  }
}
