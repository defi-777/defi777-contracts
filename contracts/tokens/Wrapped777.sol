pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "../Receiver.sol";
import "./ERC777WithGranularity.sol";

contract Wrapped777 is ERC777WithGranularity, Receiver {
  ERC20 public token;

  constructor(ERC20 _token)
    public
    ERC777WithGranularity()
  {
    token = _token;
    canReceive[address(this)] = true;

    _name = string(abi.encodePacked(token.name(), "-777"));
    _symbol = string(abi.encodePacked(token.symbol(), "777"));

    setDecimals(_token.decimals());
  }

  function wrap(uint256 amount) external {
    address sender = _msgSender();
    token.transferFrom(sender, address(this), amount);

    uint256 adjustedAmount = from20to777(amount);
    _mint(sender, adjustedAmount, "", "");
  }

  function _tokensReceived(IERC777 /*_token*/, address from, uint256 amount, bytes memory /*data*/) internal override {
    _burn(address(this), amount, "", "");

    uint256 adjustedAmount = from777to20(amount);
    token.transfer(from, adjustedAmount);
  }

  // function recover(ERC20 _token) external virtual /*onlyOwner*/ {
  //   require(!canReceive[address(_token)]);

  //   _token.transfer(msg.sender, _token.balanceOf(address(this)));
  // }
}
