// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "../../ens/ReverseENS.sol";
import "../../tokens/IWrapped777.sol";
import "../../interfaces/IWETH.sol";
import "../../Receiver.sol";
import "./interfaces/IyVault.sol";


contract YVaultAdapter is Receiver, Ownable, ReverseENS {
  mapping(address => address) public wrappedVaultToWrapper;
  mapping(address => address) public tokenToWrappedVault;
  IWETH public immutable weth;

  event MappingSet(address input, address output);

  constructor(IWETH _weth, address firstOwner) public {
    weth = _weth;

    // Needs to be explicitly set since we deploy through a Create2 proxy
    transferOwnership(firstOwner);
  }

  receive() external payable {
    if (msg.sender != address(weth)) {
      weth.deposit{ value: msg.value }();

      deposit(ERC20(address(weth)), msg.value, msg.sender);
    }
  }

  function setWrappedVault(address wrappedToken, address wrappedVault) public onlyOwner {
    wrappedVaultToWrapper[wrappedVault] = wrappedToken;
    if (wrappedToken == address(weth)) {
      tokenToWrappedVault[address(weth)] = wrappedVault;
    } else {
      tokenToWrappedVault[address(IWrapped777(wrappedToken).token())] = wrappedVault;
    }
    emit MappingSet(wrappedToken, wrappedVault);
  }

  function _tokensReceived(IERC777 token, address from, uint256 amount, bytes memory) internal override {
    address outputWrapper = wrappedVaultToWrapper[address(token)];

    ERC20 unwrappedToken = IWrapped777(address(token)).token();
    uint256 unwrappedAmount = IWrapped777(address(token)).unwrap(amount);

    if (outputWrapper == address(weth)) {
      withdrawETH(address(unwrappedToken), from, unwrappedAmount);
    } else if (outputWrapper != address(0)) {
      withdraw(address(unwrappedToken), IWrapped777(outputWrapper), from, unwrappedAmount);
    } else {
      deposit(unwrappedToken, unwrappedAmount, from);
    }
  }

  function deposit(ERC20 token, uint256 amount, address recipient) private {
    address outputWrapper = tokenToWrappedVault[address(token)];
    require(outputWrapper != address(0), 'Unsupported');
    IyVault vault = IyVault(address(IWrapped777(outputWrapper).token()));

    token.approve(address(vault), amount);
    vault.deposit(amount);

    vault.transfer(address(outputWrapper), vault.balanceOf(address(this)));
    IWrapped777(outputWrapper).gulp(recipient);
  }

  function withdraw(address _vault, IWrapped777 outputWrapper, address recipient, uint256 unwrappedAmount) private {
    IyVault vault = IyVault(_vault);
    vault.withdraw(unwrappedAmount);

    ERC20 innerToken = outputWrapper.token();
    uint256 amountToReturn = innerToken.balanceOf(address(this));
    innerToken.transfer(address(outputWrapper), amountToReturn);
    outputWrapper.gulp(recipient);
  }

  function withdrawETH(address _vault, address recipient, uint256 unwrappedAmount) private {
    IyVault vault = IyVault(_vault);
    vault.withdraw(unwrappedAmount);

    uint256 ethAmount = weth.balanceOf(address(this));
    weth.withdraw(ethAmount);
    TransferHelper.safeTransferETH(recipient, ethAmount);
  }
}
