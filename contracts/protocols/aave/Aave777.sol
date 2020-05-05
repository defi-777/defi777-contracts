pragma solidity >=0.6.5 <0.7.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "../../Receiver.sol";
import "./ILendingPool.sol";
import "./IAToken.sol";
import "./AToken777.sol";
import "./ILendingPoolAddressesProvider.sol";
import "../../tokens/IWrapped777.sol";

contract Aave777 is Receiver {
  using Address for address;

  ILendingPoolAddressesProvider private addressProvider;

  IERC1820Registry constant private _ERC1820_REGISTRY = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
  bytes32 immutable private _ATOKEN_777_INTERFACE_HASH;

  constructor(address lendingPoolAddressProvider) public {
    // mainnet address, for other addresses: https://docs.aave.com/developers/developing-on-aave/deployed-contract-instances
    addressProvider = ILendingPoolAddressesProvider(lendingPoolAddressProvider);

    _ATOKEN_777_INTERFACE_HASH = keccak256("AToken777");
  }

  function createWrapper(address wrapper) public {    
    new AToken777{salt: bytes32(0)}(addressProvider.getLendingPool(), IWrapped777(wrapper));
  }

  function calculateWrapperAddress(address wrapper) public view returns (address calculatedAddress) { 
    calculatedAddress = address(uint(keccak256(abi.encodePacked(
      byte(0xff),
      address(this),
      bytes32(0),
      keccak256(abi.encodePacked(
        type(AToken777).creationCode,
        uint256(address(addressProvider.getLendingPool())),
        uint256(wrapper)
      ))
    ))));
  }

  function getWrapperAddress(address wrappedReserve) public returns (address wrapperAddress) {
    wrapperAddress = calculateWrapperAddress(wrappedReserve);

    if(!wrapperAddress.isContract()) {
      createWrapper(wrappedReserve);
      assert(wrapperAddress.isContract());
    }
  }

  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory /*data*/) internal override {
    address implementer = _ERC1820_REGISTRY.getInterfaceImplementer(address(_token), _ATOKEN_777_INTERFACE_HASH);

    if (implementer != address(0) /* token is wrapped aToken */) {
      _token.send(address(_token), amount, abi.encode(from));
      return;
    }

    address innerToken = address(IWrapped777(address(_token)).token());
    address aToken = addressProvider.getLendingPool().core().getReserveATokenAddress(innerToken);
    if (aToken != address(0)) {
      address wrapper = address(getWrapperAddress(address(_token)));

      _token.send(wrapper, amount, abi.encode(from));
    } else {
      revert("Unsupported token");
    }
  }
}
