pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/introspection/IERC1820Registry.sol";
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

  IWrapped777 public immutable reserveWrapper;
  ERC20 public reserve;
  ILendingPool public lendingPool;

  uint16 constant private referralCode = 45;
  address private silentReceive;
  address constant private ETH_FAKE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  constructor(ILendingPool _lendingPool, IWrapped777 _reserveWrapper) public {
    lendingPool = _lendingPool;
    reserveWrapper = _reserveWrapper;

    if (address(_reserveWrapper) == ETH_FAKE_TOKEN) {
      reserve = ERC20(ETH_FAKE_TOKEN);
    } else {
      reserve = _reserveWrapper.token();
    }

    canReceive[address(this)] = true;
    canReceive[address(_reserveWrapper)] = true;

    token = ERC20(lendingPool.core().getReserveATokenAddress(address(reserve)));

    _name = string(abi.encodePacked(token.name(), "-777"));
    _symbol = string(abi.encodePacked(token.symbol(), "777"));

    setDecimals(token.decimals());
    _ERC1820_REGISTRY.setInterfaceImplementer(address(this), keccak256("AToken777"), address(this));
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
    reserve.transferFrom(sender, address(this), amount);

    reserve.approve(address(lendingPool.core()), amount);
    lendingPool.deposit(address(reserve), amount, referralCode);

    outAmount = from20to777(amount);
    _mint(sender, outAmount, "", "");
  }

  receive() external payable {
    if (silentReceive != ETH_FAKE_TOKEN) {
      depositFor(msg.sender);
    }
  }

  function depositFor(address receiver) public payable {
    require(address(reserveWrapper) == ETH_FAKE_TOKEN);
    uint256 amount = msg.value;
    lendingPool.deposit{value: amount}(ETH_FAKE_TOKEN, amount, referralCode);

    require(token.balanceOf(address(this)) == amount, "Didn't receive aTokens");
    deposit(token, receiver);

    _mint(receiver, amount, "", "");
  }

  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory data) internal override {
    if (address(_token) == silentReceive) {
      return;
    }

    address receiver = from;
    if (data.length > 0) {
      (address _receiver) = abi.decode(data, (address));
      if (_receiver != address(0)) {
        receiver = _receiver;
      }
    }

    if (address(_token) == address(this)) {
      uint adjustedAmount = from777to20(amount);
      withdraw(token, from, adjustedAmount);
      silentReceive = address(reserveWrapper);
      IAToken(address(token)).redeem(adjustedAmount);

      _burn(address(this), amount, "", "");
      transferReserveToUser(receiver, amount);
      silentReceive = address(0);
    } else if (address(_token) == address(reserveWrapper)) {
      _token.send(address(_token), amount, '');

      uint reserveAmount = reserve.balanceOf(address(this));
      reserve.approve(address(lendingPool.core()), reserveAmount);
      lendingPool.deposit(address(reserve), reserveAmount, referralCode);

      require(token.balanceOf(address(this)) == from777to20(amount), "Didn't receive aTokens");
      deposit(token, receiver);

      _mint(receiver, amount, "", "");
    } else {
      revert('Unsupported');
    }
  }

  function transferReserveToUser(address receiver, uint256 amount) private {
    if (address(reserve) == ETH_FAKE_TOKEN) {
      payable(receiver).transfer(amount);
    } else {
      reserve.approve(address(reserveWrapper), amount);

      reserveWrapper.wrap(amount);
      ERC20(address(reserveWrapper)).transfer(receiver, amount);
    }

  }

}
