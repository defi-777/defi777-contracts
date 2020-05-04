pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "../Receiver.sol";
import "./ERC777WithGranularity.sol";
import "./IWrapped777.sol";

contract Wrapped777 is ERC777WithGranularity, Receiver, IWrapped777 {
  using SafeMath for uint256;

  ERC20 public override token;
  address public override factory;

  event FlashLoan(address indexed target, uint256 amount);

  mapping(address => uint256) private borrows;

  bytes32 public DOMAIN_SEPARATOR;
  // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
  bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
  mapping(address => uint) public nonces;

  constructor(ERC20 _token)
    public
    ERC777WithGranularity()
  {
    token = _token;
    factory = msg.sender;
    canReceive[address(this)] = true;

    _name = string(abi.encodePacked(token.name(), "-777"));
    _symbol = string(abi.encodePacked(token.symbol(), "777"));

    setDecimals(_token.decimals());

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

  function wrap(uint256 amount) external override returns (uint256) {
    address sender = _msgSender();
    token.transferFrom(sender, address(this), amount);

    uint256 adjustedAmount = from20to777(amount);
    _mint(sender, adjustedAmount, "", "");
    return adjustedAmount;
  }

  function _tokensReceived(IERC777 /*_token*/, address from, uint256 amount, bytes memory data) internal override {
    _burn(address(this), amount, "", "");
    if (keccak256(data) == keccak256(bytes('flreturn'))) {
      borrows[from] = borrows[from].sub(amount);
      return;
    }

    uint256 adjustedAmount = from777to20(amount);
    token.transfer(from, adjustedAmount);
  }

  // function recover(ERC20 _token) external virtual /*onlyOwner*/ {
  //   require(!canReceive[address(_token)]);

  //   _token.transfer(msg.sender, _token.balanceOf(address(this)));
  // }

  function flashLoan(address target, uint256 amount, bytes calldata data) external {
    borrows[target] = borrows[target].add(amount);
    _mint(target, amount, data, '');

    require(borrows[target] == 0, 'Flash loan was not returned');

    emit FlashLoan(target, amount);
  }

  function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
    require(deadline >= block.timestamp, 'Permit: EXPIRED');
    bytes32 digest = keccak256(
      abi.encodePacked(
        '\x19\x01',
        DOMAIN_SEPARATOR,
        keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
      )
    );
    address recoveredAddress = ecrecover(digest, v, r, s);
    require(recoveredAddress != address(0) && recoveredAddress == owner, 'Permit: INVALID_SIGNATURE');
    _approve(owner, spender, value);
  }

  function chainId() private pure returns (uint _chainId) {
    assembly {
      _chainId := chainid()
    }
  }
}
