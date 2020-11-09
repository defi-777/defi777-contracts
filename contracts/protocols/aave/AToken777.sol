pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/introspection/IERC1820Registry.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "../../GuardedReceiver.sol";
import "../../tokens/IWrapped777.sol";
import "./ERC777WithoutBalance.sol";
import "./IAToken.sol";
import "./ILendingPool.sol";
import "./WadRayMath.sol";

contract AToken777 is ERC777WithoutBalance, IWrapped777, GuardedReceiver {
  using WadRayMath for uint256;
  using SafeMath for uint256;

  ERC20 public immutable override token;

  IWrapped777 public immutable reserveWrapper;
  ERC20 public reserve;
  ILendingPool public lendingPool;

  uint16 constant private referralCode = 45;
  address private silentReceive;
  address constant private ETH_FAKE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  mapping(address => uint256) private balance;
  mapping(address => uint256) private userIndexes;

  constructor(ILendingPool _lendingPool, IWrapped777 _reserveWrapper) public {
    lendingPool = _lendingPool;
    reserveWrapper = _reserveWrapper;

    if (address(_reserveWrapper) == ETH_FAKE_TOKEN) {
      reserve = ERC20(ETH_FAKE_TOKEN);
    } else {
      reserve = _reserveWrapper.token();
    }

    whitelistReceiveToken(address(this));
    whitelistReceiveToken(address(_reserveWrapper));

    ERC20 _token = ERC20(_lendingPool.core().getReserveATokenAddress(address(reserve)));
    token = _token;

    _name = string(abi.encodePacked(_token.name(), "-777"));
    _symbol = string(abi.encodePacked(_token.symbol(), "777"));

    setDecimals(_token.decimals());
    _ERC1820_REGISTRY.setInterfaceImplementer(address(this), keccak256("AToken777"), address(this));
  }

  function balanceOf(address tokenHolder) public view override(ERC777WithoutBalance, IERC777) returns (uint256) {
    uint256 reserveNormalizedIncome = lendingPool.core().getReserveNormalizedIncome(address(reserve));
    return from20to777(getReserveBalance(tokenHolder, reserveNormalizedIncome));
  }

  function getReserveBalance(address tokenHolder, uint256 reserveNormalizedIncome) internal view returns (uint256) {
    if (balance[tokenHolder] == 0) {
      return 0;
    }

    return balance[tokenHolder]
      .wadToRay()
      .rayMul(reserveNormalizedIncome)
      .rayDiv(userIndexes[tokenHolder])
      .rayToWad();
  }

  function totalSupply() public view override(ERC777WithoutBalance, IERC777) returns (uint256) {
    return from20to777(token.balanceOf(address(this)));
  }

  function update(address account) internal {
    uint256 reserveNormalizedIncome = lendingPool.core().getReserveNormalizedIncome(address(reserve));
    balance[account] = getReserveBalance(account, reserveNormalizedIncome);
    userIndexes[account] = reserveNormalizedIncome;
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
      update(from);
      update(to);

      balance[from] = balance[from].sub(amount);
      balance[to] = balance[to].add(amount);
    }
  }

  function wrap(uint256 amount) external override returns (uint256 outAmount) {
    address sender = _msgSender();
    reserve.transferFrom(sender, address(this), amount);

    _wrap(amount, sender);
  }

  function wrapTo(uint256 amount, address recipient) external override returns (uint256 outAmount) {
    address sender = _msgSender();
    reserve.transferFrom(sender, address(this), amount);

    _wrap(amount, recipient);
  }

  function gulp(address recipient) external override returns (uint256 outAmount) {
    _wrap(reserve.balanceOf(address(this)), recipient);
  }

  function _wrap(uint256 amount, address recipient) private returns (uint256 outAmount) {
    update(recipient);
    balance[recipient] = balance[recipient].add(amount);

    reserve.approve(address(lendingPool.core()), amount);
    lendingPool.deposit(address(reserve), amount, referralCode);

    outAmount = from20to777(amount);
    _mint(recipient, outAmount, "", "");
  }

  function unwrap(uint256 amount) external override returns (uint256 unwrappedAmount) {
    address sender = _msgSender();
    return _unwrap(amount, sender, sender);
  }

  function unwrapTo(uint256 amount, address recipient) external override returns (uint256 unwrappedAmount) {
    return _unwrap(amount, _msgSender(), recipient);
  }

  function _unwrap(uint256 amount, address from, address recipient) private returns (uint256 unwrappedAmount) {
    update(from);

    unwrappedAmount = from777to20(amount);
    balance[from] = balance[from].sub(unwrappedAmount);
    _burn(address(this), amount, "", "");

    TransferHelper.safeTransfer(address(token), recipient, unwrappedAmount);
  }

  receive() external payable {
    if (silentReceive != ETH_FAKE_TOKEN) {
      depositFor(msg.sender);
    }
  }

  function depositFor(address receiver) public payable {
    require(address(reserveWrapper) == ETH_FAKE_TOKEN);
    update(receiver);

    uint256 amount = msg.value;
    balance[receiver] = balance[receiver].add(amount);

    lendingPool.deposit{value: amount}(ETH_FAKE_TOKEN, amount, referralCode);

    require(token.balanceOf(address(this)) == amount, "Didn't receive aTokens");

    _mint(receiver, amount, "", "");
  }

  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory data) internal override {
    if (address(_token) == silentReceive) {
      return;
    }

    update(from);

    address receiver = from;
    if (data.length > 0) {
      (address _receiver) = abi.decode(data, (address));
      if (_receiver != address(0)) {
        receiver = _receiver;
        update(receiver);
      }
    }

    if (address(_token) == address(this)) {
      withdraw(amount, from, receiver);
    } else if (address(_token) == address(reserveWrapper)) {
      deposit(_token, amount, receiver);
    } else {
      revert('Unsupported');
    }
  }

  function withdraw(uint256 amount, address from, address recipient) private {
    uint adjustedAmount = from777to20(amount);

    balance[from] = balance[from].sub(adjustedAmount);
    silentReceive = address(reserveWrapper);
    IAToken(address(token)).redeem(adjustedAmount);

    _burn(address(this), amount, "", "");
    transferReserveToUser(recipient, amount);
    silentReceive = address(0);
  }

  function deposit(IERC777 wrapper, uint256 amount, address recipient) private {
    wrapper.send(address(wrapper), amount, '');

    uint reserveAmount = reserve.balanceOf(address(this));
    balance[recipient] = balance[recipient].add(reserveAmount);
    reserve.approve(address(lendingPool.core()), reserveAmount);
    lendingPool.deposit(address(reserve), reserveAmount, referralCode);

    userIndexes[recipient] = lendingPool.core().getReserveNormalizedIncome(address(reserve));
    _mint(recipient, from20to777(reserveAmount), "", "");

  }

  function transferReserveToUser(address receiver, uint256 amount) private {
    if (address(reserve) == ETH_FAKE_TOKEN) {
      payable(receiver).transfer(amount);
    } else {
      reserve.approve(address(reserveWrapper), amount);

      reserveWrapper.wrapTo(amount, receiver);
    }
  }

}
