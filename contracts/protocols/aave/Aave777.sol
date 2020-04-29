pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "../../Receiver.sol";
import "./ILendingPool.sol";
import "./IAToken.sol";
import "./AToken777.sol";
import "./ILendingPoolAddressesProvider.sol";
import "../../tokens/IWrapped777.sol";

contract Aave777 is Receiver {
  using Address for address;

  address private wrapLock;

  ILendingPoolAddressesProvider private addressProvider;

  constructor(address lendingPoolAddressProvider) public {
    // mainnet address, for other addresses: https://docs.aave.com/developers/developing-on-aave/deployed-contract-instances
    addressProvider = ILendingPoolAddressesProvider(lendingPoolAddressProvider);
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
    if (address(_token) == wrapLock) {
      return;
    }

    if (false/* token is wrapped aToken */) {
      _token.send(address(_token), amount, "");
      // IAToken aToken = IAToken(AToken777(_token).token());
      // aToken.redeem();
    } else if (addressProvider.getLendingPool().core().getReserveATokenAddress(address(IWrapped777(address(_token)).token())) != address(0)) {
      AToken777 wrapper = AToken777(getWrapperAddress(address(_token)));
      wrapLock = address(wrapper);

      _token.send(address(wrapper), amount, '');
      wrapper.transfer(from, amount);
    } else {
      revert("Unsupported token");
    }
    wrapLock = address(0);
  }
}
