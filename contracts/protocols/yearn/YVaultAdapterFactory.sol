// SPDX-License-Identifier: MIT
pragma solidity >=0.6.3 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../../tokens/IWrapped777.sol";
import "./YVaultAdapter.sol";
import "./IYVaultAdapterFactory.sol";


contract YVaultAdapterFactory is IYVaultAdapterFactory {
  using Address for address;

  address private _nextVaultWrapper;
  address private _nextTokenWrapper;
  address private immutable _weth;

  bytes32 public constant ADAPTER_BYTECODE_HASH = keccak256(type(YVaultAdapter).creationCode);

  event AdapterCreated(address vaultWrapper, address tokenWrapper);

  constructor(address __weth) public {
    _weth = __weth;
  }

  function calculateAdapterAddress(address vaultWrapper, address tokenWrapper) public view returns (address calculatedAddress) {
    calculatedAddress = address(uint(keccak256(abi.encodePacked(
      byte(0xff),
      address(this),
      keccak256(abi.encodePacked(vaultWrapper, tokenWrapper)),
      ADAPTER_BYTECODE_HASH
    ))));
  }

  function createAdapter(address vaultWrapper, address tokenWrapper) public {
    _nextVaultWrapper = vaultWrapper;
    _nextTokenWrapper = tokenWrapper;
    new YVaultAdapter{salt: keccak256(abi.encodePacked(vaultWrapper, tokenWrapper))}();
    _nextVaultWrapper = address(0);
    _nextTokenWrapper = address(0);

    emit AdapterCreated(vaultWrapper, tokenWrapper);
  }

  function getAdapterAddress(address vaultWrapper, address tokenWrapper) public returns (address adapterAddress) {
    adapterAddress = calculateAdapterAddress(vaultWrapper, tokenWrapper);

    if(!adapterAddress.isContract()) {
      createAdapter(vaultWrapper, tokenWrapper);
      assert(adapterAddress.isContract());
    }
  }

  function nextWrappers() external override view returns (address, address) {
    return (_nextVaultWrapper, _nextTokenWrapper);
  }

  function weth() external override view returns (address) {
    return _weth;
  }
}
