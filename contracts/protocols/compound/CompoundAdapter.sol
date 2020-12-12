// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "../../ens/ReverseENS.sol";
import "../../tokens/IWrapped777.sol";
import "../../Receiver.sol";
import "./interfaces/ICToken.sol";
import "./interfaces/ICEther.sol";

contract CompoundAdapter is Receiver, Ownable, ReverseENS {
  mapping(address => address) public wrappedCTokenToWrapper;
  mapping(address => address) public tokenToWrappedCToken;
  address private constant ETHER = address(1);
  uint256 private unwrapping = 1;

  event MappingSet(address input, address output);

  constructor() public {
    // Needs to be explicitly set since we deploy through a Create2 proxy
    transferOwnership(tx.origin);
  }

  receive() external payable {
    if (unwrapping == 0) {
      return;
    }

    address outputWrapper = tokenToWrappedCToken[ETHER];
    require(outputWrapper != address(0), 'Unsupported');

    ICEther cToken = ICEther(address(IWrapped777(outputWrapper).token()));
    cToken.mint{ value: msg.value }();
    cToken.transfer(outputWrapper, cToken.balanceOf(address(this)));
    IWrapped777(outputWrapper).gulp(msg.sender);
  }

  function setWrappedCToken(address wrappedToken, address wrappedAToken) public onlyOwner {
    wrappedCTokenToWrapper[wrappedAToken] = wrappedToken;
    if (wrappedToken == address(1)) {
      tokenToWrappedCToken[address(1)] = wrappedAToken;
    } else {
      tokenToWrappedCToken[address(IWrapped777(wrappedToken).token())] = wrappedAToken;
    }
    emit MappingSet(wrappedToken, wrappedAToken);
  }

  function _tokensReceived(IERC777 token, address from, uint256 amount, bytes memory) internal override {
    address outputWrapper = wrappedCTokenToWrapper[address(token)];

    ERC20 unwrappedToken = IWrapped777(address(token)).token();
    uint256 unwrappedAmount = IWrapped777(address(token)).unwrap(amount);

    if (outputWrapper == ETHER) {
      withdrawETH(address(unwrappedToken), unwrappedAmount, from);
    } else if (outputWrapper != address(0)) {
      withdraw(address(unwrappedToken), IWrapped777(outputWrapper), from, unwrappedAmount);
    } else {
      deposit(unwrappedToken, unwrappedAmount, from);
    }
  }

  function deposit(ERC20 token, uint256 amount, address recipient) private {
    address outputWrapper = tokenToWrappedCToken[address(token)];
    require(outputWrapper != address(0), 'Unsupported');

    ICToken cToken = ICToken(address(IWrapped777(outputWrapper).token()));
    token.approve(address(cToken), amount);
    cToken.mint(amount);

    cToken.transfer(outputWrapper, cToken.balanceOf(address(this)));
    IWrapped777(outputWrapper).gulp(recipient);
  }

  function withdraw(address token, IWrapped777 outputWrapper, address recipient, uint256 amount) private {
    ICToken cToken = ICToken(token);
    cToken.redeem(amount);

    IERC20 underlying = IERC20(cToken.underlying());
    underlying.transfer(address(outputWrapper), underlying.balanceOf(address(this)));
    outputWrapper.gulp(recipient);
  }

  function withdrawETH(address token, uint256 amount, address recipient) private {
    ICEther cToken = ICEther(token);

    unwrapping = 0;
    cToken.redeem(amount);
    unwrapping = 1;

    TransferHelper.safeTransferETH(recipient, address(this).balance);
  }
}
