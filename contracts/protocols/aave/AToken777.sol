pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "../../Receiver.sol";
import "../../tokens/IWrapped777.sol";
import "./ERC777WithoutBalance.sol";
import "./IAToken.sol";
import "./ILendingPool.sol";
import "./Vault.sol";

contract AToken777 is ERC777WithoutBalance, IWrapped777, Receiver, Vault {
  ERC20 public override token;
  address public override factory;

  IWrapped777 public reserveWrapper;
  ILendingPool public lendingPool;

  address private silentReceive;

  constructor(ILendingPool _lendingPool, IWrapped777 _reserveWrapper) public {
    lendingPool = _lendingPool;
    reserveWrapper = _reserveWrapper;

    canReceive[address(this)] = true;
    canReceive[address(_reserveWrapper)] = true;

    token = ERC20(lendingPool.core().getReserveATokenAddress(address(_reserveWrapper.token())));

    _name = string(abi.encodePacked(token.name(), "-777"));
    _symbol = string(abi.encodePacked(token.symbol(), "777"));

    setDecimals(token.decimals());
  }

  function balanceOf(address tokenHolder) public view override(ERC777WithoutBalance, IERC777) returns (uint256) {
    return from20to777(vaultBalance(token, tokenHolder));
  }

  function totalSupply() public view override(ERC777WithoutBalance, IERC777) returns (uint256) {
    return ERC777WithoutBalance.totalSupply();
  }

  function _move(
    address /*operator*/,
    address from,
    address to,
    uint256 amount,
    bytes memory /*userData*/,
    bytes memory /*operatorData*/
  ) internal override {
    if (to != address(this)) {
      Vault.transfer(token, from, to, from777to20(amount));
    }
  }

  function wrap(uint256 amount) external override returns (uint256 outAmount) {
    address sender = _msgSender();
    reserveWrapper.token().transferFrom(sender, address(this), amount);

    reserveWrapper.token().approve(address(lendingPool.core()), amount);
    uint16 referralCode = 0;
    lendingPool.deposit(address(reserveWrapper.token()), amount, referralCode);

    outAmount = from20to777(amount);
    _mint(sender, outAmount, "", "");
  }

  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory /*data*/) internal override {
    if (address(_token) == silentReceive) {
      return;
    }

    if (address(_token) == address(this)) {

      uint adjustedAmount = from777to20(amount);
      withdraw(token, from, adjustedAmount);
      IAToken(address(token)).redeem(adjustedAmount);

      reserveWrapper.token().approve(address(reserveWrapper), adjustedAmount);

      silentReceive = address(reserveWrapper);
      reserveWrapper.wrap(adjustedAmount);
      silentReceive = address(0);

      _burn(address(this), amount, "", "");
      ERC20(address(reserveWrapper)).transfer(from, amount);
    } else if (address(_token) == address(reserveWrapper)) {
      _token.send(address(_token), amount, '');

      ERC20 reserveToken = reserveWrapper.token();
      uint reserveAmount = reserveToken.balanceOf(address(this));
      reserveToken.approve(address(lendingPool.core()), reserveAmount);
      uint16 referralCode = 0;
      lendingPool.deposit(address(reserveToken), reserveAmount, referralCode);

      require(token.balanceOf(address(this)) == from777to20(amount), "Didn't receive aTokens");
      deposit(token, from);

      _mint(from, amount, "", "");
    } else {
      revert('Unsupported');
    }
  }

}
