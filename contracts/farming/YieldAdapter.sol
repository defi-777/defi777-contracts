// SPDX-License-Identifier: MIT
pragma solidity >=0.6.5 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/introspection/IERC1820Registry.sol";
import "@uniswap/lib/contracts/libraries/SafeERC20Namer.sol";
import "../tokens/Granularity.sol";
import "../tokens/IWrapped777.sol";
import "../InfiniteApprove.sol";
import "./IFarmerToken.sol";
import "./IYieldAdapterFactory.sol";

contract YieldAdapter is Context, IERC777, IERC20, Granularity, InfiniteApprove {
  using SafeMath for uint256;
  using Address for address;

  IERC1820Registry constant internal _ERC1820_REGISTRY = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

  IFarmerToken public immutable farmer;
  address public immutable token;
  IWrapped777 public immutable wrapper;

  string internal _name;
  string internal _symbol;

  mapping(address => mapping(address => bool)) private _operators;

  // ERC20-allowances
  mapping (address => mapping (address => uint256)) private _allowances;


  // keccak256("ERC777TokensRecipient")
  bytes32 constant private _TOKENS_RECIPIENT_INTERFACE_HASH = keccak256("ERC777TokensRecipient");

  constructor() public {
    IYieldAdapterFactory factory = IYieldAdapterFactory(msg.sender);
    farmer = IFarmerToken(factory.nextToken());
    IWrapped777 _wrapper = IWrapped777(factory.nextReward());
    ERC20 _token = _wrapper.token();
    token = address(_token);
    wrapper = _wrapper;

    _name = string(abi.encodePacked(SafeERC20Namer.tokenName(address(_token)), "-777 Yield"));
    _symbol = string(abi.encodePacked(SafeERC20Namer.tokenSymbol(address(_token)), "777y"));

    setDecimals(_token.decimals());

    // register interfaces
    _ERC1820_REGISTRY.setInterfaceImplementer(address(this), keccak256("ERC777Token"), address(this));
    _ERC1820_REGISTRY.setInterfaceImplementer(address(this), keccak256("ERC20Token"), address(this));
  }

  /**
   * @dev See {IERC777-name}.
   */
  function name() public view override returns (string memory) {
    return _name;
  }

  /**
   * @dev See {IERC777-symbol}.
   */
  function symbol() public view override returns (string memory) {
    return _symbol;
  }

  /**
   * @dev See {ERC20-decimals}.
   *
   * Always returns 18, as per the
   * [ERC777 EIP](https://eips.ethereum.org/EIPS/eip-777#backward-compatibility).
   */
  function decimals() public pure returns (uint8) {
    return 18;
  }

  /**
   * @dev See {IERC777-granularity}.
   *
   * This implementation always returns `1`.
   */
  function granularity() public view override returns (uint256) {
    return getGranularity();
  }

  /**
   * @dev See {IERC777-totalSupply}.
   */
  function totalSupply() public view override(IERC20, IERC777) virtual returns (uint256) {
    return IERC20(token).balanceOf(address(farmer));
  }

  function balanceOf(address account) external view override(IERC20, IERC777) virtual returns (uint256) {
    return farmer.rewardBalance(token, account);
  }

  /**
   * @dev See {IERC777-send}.
   *
   * Also emits a {IERC20-Transfer} event for ERC20 compatibility.
   */
  function send(address recipient, uint256 amount, bytes memory data) public override  {
    _send(_msgSender(), recipient, amount, data, "", true);
  }

  /**
   * @dev See {IERC20-transfer}.
   *
   * Unlike `send`, `recipient` is _not_ required to implement the {IERC777Recipient}
   * interface if it is a contract.
   *
   * Also emits a {Sent} event.
   */
  function transfer(address recipient, uint256 amount) public override returns (bool) {
    require(recipient != address(0), "ERC777: transfer to the zero address");

    address from = _msgSender();

    _move(from, from, recipient, amount, "", "");

    return true;
  }

  /**
   * @dev See {IERC777-burn}.
   *
   * Also emits a {IERC20-Transfer} event for ERC20 compatibility.
   */
  function burn(uint256, bytes memory) public override {
    revert("Not supported");
  }

  /**
   * @dev See {IERC777-isOperatorFor}.
   */
  function isOperatorFor(
    address operator,
    address tokenHolder
  ) public view override returns (bool) {
    return operator == tokenHolder ||
      _operators[tokenHolder][operator];
  }

  /**
   * @dev See {IERC777-authorizeOperator}.
   */
  function authorizeOperator(address operator) public override  {
    require(_msgSender() != operator, "ERC777: authorizing self as operator");
    _operators[_msgSender()][operator] = true;

    emit AuthorizedOperator(operator, _msgSender());
  }

  /**
   * @dev See {IERC777-revokeOperator}.
   */
  function revokeOperator(address operator) public override  {
    require(operator != _msgSender(), "ERC777: revoking self as operator");
    delete _operators[_msgSender()][operator];

    emit RevokedOperator(operator, _msgSender());
  }

  /**
   * @dev See {IERC777-defaultOperators}.
   */
  function defaultOperators() public view override returns (address[] memory) {}

  /**
   * @dev See {IERC777-operatorSend}.
   *
   * Emits {Sent} and {IERC20-Transfer} events.
   */
  function operatorSend(
      address sender,
      address recipient,
      uint256 amount,
      bytes memory data,
      bytes memory operatorData
  ) public override {
    require(isOperatorFor(_msgSender(), sender), "ERC777: caller is not an operator for holder");
    _send(sender, recipient, amount, data, operatorData, true);
  }

  /**
   * @dev See {IERC777-operatorBurn}.
   *
   * Emits {Burned} and {IERC20-Transfer} events.
   */
  function operatorBurn(address, uint256, bytes memory, bytes memory) public override {
    revert("Not supported");
  }

  /**
   * @dev See {IERC20-allowance}.
   *
   * Note that operator and allowance concepts are orthogonal: operators may
   * not have allowance, and accounts with allowance may not be operators
   * themselves.
   */
  function allowance(address holder, address spender) public view override returns (uint256) {
    return _allowances[holder][spender];
  }

  /**
   * @dev See {IERC20-approve}.
   *
   * Note that accounts cannot have allowance issued by their operators.
   */
  function approve(address spender, uint256 value) public override returns (bool) {
    address holder = _msgSender();
    _approve(holder, spender, value);
    return true;
  }

 /**
  * @dev See {IERC20-transferFrom}.
  *
  * Note that operator and allowance concepts are orthogonal: operators cannot
  * call `transferFrom` (unless they have allowance), and accounts with
  * allowance cannot call `operatorSend` (unless they are operators).
  *
  * Emits {Sent}, {IERC20-Transfer} and {IERC20-Approval} events.
  */
  function transferFrom(address holder, address recipient, uint256 amount) public override returns (bool) {
    require(recipient != address(0), "ERC777: transfer to the zero address");
    require(holder != address(0), "ERC777: transfer from the zero address");

    address spender = _msgSender();

    _move(spender, holder, recipient, amount, "", "");
    _approve(holder, spender, _allowances[holder][spender].sub(amount, "ERC777: transfer amount exceeds allowance"));

    return true;
  }

  /**
   * @dev Send tokens
   * @param from address token holder address
   * @param to address recipient address
   * @param amount uint256 amount of tokens to transfer
   * @param userData bytes extra information provided by the token holder (if any)
   * @param operatorData bytes extra information provided by the operator (if any)
   */
  function _send(
    address from,
    address to,
    uint256 amount,
    bytes memory userData,
    bytes memory operatorData,
    bool /*requireReceptionAck*/
  ) internal {
    require(from != address(0), "ERC777: send from the zero address");
    require(to != address(0), "ERC777: send to the zero address");

    address operator = _msgSender();

    _move(operator, from, to, amount, userData, operatorData);
  }

  function _move(
    address operator,
    address from,
    address to,
    uint256 amount,
    bytes memory userData,
    bytes memory operatorData
  ) internal virtual {
    require(amount % getGranularity() == 0, "ERC777: Invalid granularity");

    uint256 adjustedAmount = from777to20(amount);
    farmer.withdrawFrom(token, from, address(wrapper), adjustedAmount);

    uint wrappedAmount = wrapper.gulp(to);
    require(wrappedAmount >= amount);

    emit Sent(operator, from, to, amount, userData, operatorData);
    emit Transfer(from, to, amount);
  }

  function _approve(address holder, address spender, uint256 value) internal {
    // TODO: restore this require statement if this function becomes internal, or is called at a new callsite. It is
    // currently unnecessary.
    //require(holder != address(0), "ERC777: approve from the zero address");
    require(spender != address(0), "ERC777: approve to the zero address");

    _allowances[holder][spender] = value;
    emit Approval(holder, spender, value);
  }
}
