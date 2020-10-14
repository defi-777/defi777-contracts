// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/introspection/IERC1820Registry.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../Receiver.sol";
import "../../InfiniteApprove.sol";
import "../../tokens/IWrapped777.sol";
import "../../interfaces/IWETH.sol";
import "./interfaces/IyVault.sol";
import "./IYVaultAdapterFactory.sol";


contract YVaultAdapter is Receiver, InfiniteApprove {
  IWrapped777 public immutable vaultWrapper;
  IWrapped777 public immutable tokenWrapper;
  IyVault public immutable vault;
  ERC20 public immutable innerToken;

  constructor() public {
    IYVaultAdapterFactory factory = IYVaultAdapterFactory(msg.sender);
    (address _vaultWrapper, address _tokenWrapper) = factory.nextWrappers();

    ERC20 _innerToken;
    if (address(_tokenWrapper) == address(0)) {
      _innerToken = ERC20(factory.weth());
    } else {
      _innerToken = ERC20(IWrapped777(_tokenWrapper).token());
    }

    vaultWrapper = IWrapped777(_vaultWrapper);
    tokenWrapper = IWrapped777(_tokenWrapper);
    vault = IyVault(address(IWrapped777(_vaultWrapper).token()));
    innerToken = _innerToken;
  }

  receive() external payable {
    // Only allow eth sent from WETH
    // require(msg.sender == address(innerToken));
    if (msg.sender != address(innerToken)) {
      IWETH(address(innerToken)).deposit{ value: msg.value }();
      deposit(msg.value, msg.sender);
    }
  }

  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory /*data*/) internal override {
    IWrapped777 inputWrapper = IWrapped777(address(_token));
    ERC20 unwrappedToken = inputWrapper.token();

    uint256 unwrappedAmount = inputWrapper.unwrap(amount);

    if (address(unwrappedToken) == address(vault)) {
      // Exit
      vault.withdraw(unwrappedAmount);
      uint256 amountToReturn = innerToken.balanceOf(address(this));

      if (address(tokenWrapper) == address(0)) {
        IWETH(address(innerToken)).withdraw(amountToReturn);
        (bool success,) = payable(from).call{value: amountToReturn}("");
        require(success);
      } else {
        innerToken.transfer(address(tokenWrapper), amountToReturn);
        tokenWrapper.gulp(from);
      }
    } else if (address(unwrappedToken) == address(innerToken)) {
      deposit(unwrappedAmount, from);
    } else {
      revert('UNSUPPORTED');
    }
  }

  function deposit(uint256 amount, address recipient) private {
    infiniteApprove(innerToken, address(vault), amount);
    vault.deposit(amount);

    vault.transfer(address(vaultWrapper), vault.balanceOf(address(this)));
    vaultWrapper.gulp(recipient);
  }
}
