// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC777/IERC777.sol";
import "../tokens/Wrapped777.sol";
import "../Receiver.sol";

contract TestFlashLoanRecipient is Receiver {
  uint256 private amount;
  address private token;

  function runFlashLoan(Wrapped777 _token, uint256 _amount) external {
    amount = _amount;
    token = address(_token);

    _token.flashMint(address(this), _amount, bytes('test'));
  }

  function runInvalidFlashLoan(Wrapped777 _token, uint256 _amount) external {
    token = 0x0000000000000000000000000000000000000000;
    _token.flashMint(address(this), _amount, bytes('test'));
  }

  function _tokensReceived(IERC777 _token, address /*from*/, uint256 _amount, bytes memory data) internal override {
    if (address(_token) == token) {
      require(amount == _amount, 'Incorrect amount');
      require(keccak256(data) == keccak256(bytes('test')), 'Wrong data');

      require(_token.balanceOf(address(this)) == amount, 'Incorrect balance');
    } else {
      Wrapped777(address(_token)).transfer(0x0000000000000000000000000000000000000001, 1);
    }
  }
}
