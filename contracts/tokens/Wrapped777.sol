// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "@uniswap/lib/contracts/libraries/SafeERC20Namer.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "../Receiver.sol";
import "./ERC777WithGranularity.sol";
import "./IWrapperFactory.sol";
import "./IWrapped777.sol";
import "./IPermit.sol";

contract Wrapped777 is ERC777WithGranularity, Receiver, IWrapped777 {
  using SafeMath for uint256;

  string public constant WRAPPER_VERSION = "0.2.0";

  ERC20 public immutable override token;

  event FlashMint(address indexed target, uint256 amount);

  ////////// For permit:
  bytes32 public immutable DOMAIN_SEPARATOR;
  // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
  bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
  mapping(address => uint) public nonces;

  constructor() public {
    address _token = IWrapperFactory(msg.sender).nextToken();
    token = ERC20(_token);

    _name = string(abi.encodePacked(SafeERC20Namer.tokenName(_token), "-777"));
    _symbol = string(abi.encodePacked(SafeERC20Namer.tokenSymbol(_token), "777"));

    setDecimals(ERC20(_token).decimals());

    ERC1820_REGISTRY.setInterfaceImplementer(address(this), keccak256("Wrapped777"), address(this));

    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
        keccak256(bytes(_name)),
        keccak256(bytes('1')),
        chainId(),
        address(this)
      )
    );
  }

  function totalSupply() public view override(ERC777WithGranularity, IERC777) returns (uint256) {
    return ERC777WithGranularity.totalSupply();
  }

  function balanceOf(address tokenHolder) public view override(ERC777WithGranularity, IERC777) returns (uint256) {
    return ERC777WithGranularity.balanceOf(tokenHolder);
  }

  /**
   * @dev Wraps ERC-20 tokens from the caller and sends wrapped tokens to the caller
   *
   * @param amount Number of tokens to wrap
   * @return Amount of wrapper tokens minted (same as the input amount if the token has 18 decimals)
   */
  function wrap(uint256 amount) external override returns (uint256) {
    address sender = _msgSender();
    return _wrap(sender, amount);
  }

  /**
   * @dev Same as wrap(), but approves the token transfer using a ERC2612 permit signature
   *
   * @param value Number of tokens to wrap
   * @return Amount of wrapper tokens minted (same as the input amount if the token has 18 decimals)
   */
  function wrapWithPermit(uint value, uint deadline, uint256 nonce, uint8 v, bytes32 r, bytes32 s) external returns (uint256) {
    address sender = _msgSender();
    try IPermit(address(token)).permit(sender, address(this), value, deadline, v, r, s) {
    } catch {
      // Dai
      IPermit(address(token)).permit(sender, address(this), nonce, deadline, true /* allowed */, v, r, s);
    }

    return _wrap(sender, value);
  }

  function _wrap(address sender, uint256 amount) private returns (uint256 outputAmount) {
    TransferHelper.safeTransferFrom(address(token), sender, address(this), amount);

    outputAmount = from20to777(amount);
    _mint(sender, outputAmount, "", "");
  }

  /**
   * @dev Same as wrap(), but allows setting a recipient address
   *
   * @param amount Number of tokens to wrap
   * @param recipient Address to receive tokens
   * @return outputAmount Amount of wrapper tokens minted (same as the input amount if the token has 18 decimals)
   */
  function wrapTo(uint256 amount, address recipient) external override returns (uint256 outputAmount) {
    address sender = _msgSender();
    TransferHelper.safeTransferFrom(address(token), sender, address(this), amount);

    outputAmount = from20to777(amount);
    _mint(recipient, outputAmount, "", "");
  }

  /**
   * @dev Same as wrap(), but allows setting a recipient address
   *
   * @param amount Number of tokens to wrap
   * @param recipient Address to receive tokens
   * @return amount Amount of wrapper tokens minted (same as the input amount if the token has 18 decimals)
   */
  function gulp(address recipient) external override returns (uint256 amount) {
    amount = from20to777(token.balanceOf(address(this))).sub(ERC777WithGranularity.totalSupply());
    _mint(recipient, amount, "", "");
  }

  /**
   * @dev Unwraps tokens from the sender, returns them the inner ERC-20
   *
   * @param amount Number of tokens to unwrap
   * @return unwrappedAmount Amount of unwrapped tokens (same as the input amount if the token has 18 decimals)
   */
  function unwrap(uint256 amount) external override returns (uint256 unwrappedAmount) {
    address sender = _msgSender();
    return _unwrap(amount, sender, sender);
  }


  /**
   * @dev Same as unwrap(), but sends unwrapped tokens to separate address
   *
   * @param amount Number of tokens to unwrap
   * @param recipient Address to receive the tokens
   * @return unwrappedAmount Amount of unwrapped tokens (same as the input amount if the token has 18 decimals)
   */
  function unwrapTo(uint256 amount, address recipient) external override returns (uint256 unwrappedAmount) {
    return _unwrap(amount, _msgSender(), recipient);
  }

  function _unwrap(uint256 amount, address from, address recipient) private returns (uint256 unwrappedAmount) {
    _burn(from, amount, "", "");

    unwrappedAmount = from777to20(amount);
    TransferHelper.safeTransfer(address(token), recipient, unwrappedAmount);
  }

  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory data) internal override {
    if (address(_token) != address(this)) {
      tryTokenUpgrade(address(_token), from, amount);
      return;
    }

    _burn(address(this), amount, "", "");

    uint256 adjustedAmount = from777to20(amount);
    TransferHelper.safeTransfer(address(token), from, adjustedAmount);
  }

  /**
   * @dev Mints an unbounded amount of wrapper tokens to the target. Tokens must be repaid by the
   * end of the transaction, or it will revert.
   *
   * @param target Address to receive the tokens (must be a ERC777Recipient)
   * @param amount Number of tokens to mint
   * @param data Arbitrary data to pass to the receive hook
   */
  function flashMint(address target, uint256 amount, bytes calldata data) external {
    _mint(target, amount, data, '');
    _burn(target, amount, data, '');

    emit FlashMint(target, amount);
  }

  function tryTokenUpgrade(address oldWrapper, address sender, uint256 amount) private {
    if (address(Wrapped777(oldWrapper).token()) != address(token)) {
      revert("INVALID");
    }

    uint256 startingBalance = token.balanceOf(address(this));

    TransferHelper.safeTransfer(oldWrapper, oldWrapper, amount);

    uint256 endBalance = token.balanceOf(address(this));

    uint256 numUpgradedTokens = from20to777(endBalance.sub(startingBalance));
    require(numUpgradedTokens > 0, "NO-UPGRADE");

    _mint(sender, numUpgradedTokens, "", "");
  }

  /**
   * @dev ERC2612 permit
   */
  function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
    require(deadline >= block.timestamp, 'EXPIRED');
    bytes32 digest = keccak256(
      abi.encodePacked(
        '\x19\x01',
        DOMAIN_SEPARATOR,
        keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
      )
    );
    address recoveredAddress = ecrecover(digest, v, r, s);
    require(recoveredAddress != address(0) && recoveredAddress == owner, 'Permit INVALID_SIG');
    _approve(owner, spender, value);
  }

  function chainId() private pure returns (uint _chainId) {
    assembly {
      _chainId := chainid()
    }
  }
}
