// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./YieldAdapter.sol";
import "./IYieldAdapterFactory.sol";


contract YieldAdapterFactory is IYieldAdapterFactory {
  using Address for address;

  address private _nextToken;
  address private _nextReward;

  bytes32 public constant ADAPTER_HASH = keccak256(type(YieldAdapter).creationCode);

  event WrapperCreated(address farmerToken, address rewardWrapper);

  function calculateWrapperAddress(address farmerToken, address rewardWrapper) external view override returns (address calculatedAddress) {
    calculatedAddress = _calculateWrapperAddress(farmerToken, rewardWrapper);
  }

  function _calculateWrapperAddress(address farmerToken, address rewardWrapper) private view returns (address calculatedAddress) {
    calculatedAddress = address(uint(keccak256(abi.encodePacked(
      byte(0xff),
      address(this),
      keccak256(abi.encodePacked(farmerToken, rewardWrapper)),
      ADAPTER_HASH
    ))));
  }

  function createWrapper(address farmerToken, address rewardWrapper) external override {
    _createWrapper(farmerToken, rewardWrapper);
  }

  function _createWrapper(address farmerToken, address rewardWrapper) private {
    _nextToken = farmerToken;
    _nextReward = rewardWrapper;
    new YieldAdapter{salt: keccak256(abi.encodePacked(farmerToken, rewardWrapper))}();
    _nextToken = address(0);
    _nextReward = address(0);

    emit WrapperCreated(farmerToken, rewardWrapper);
  }

  function getWrapperAddress(address farmerToken, address rewardWrapper) external override returns (address wrapperAddress) {
    wrapperAddress = _calculateWrapperAddress(farmerToken, rewardWrapper);

    if(!wrapperAddress.isContract()) {
      _createWrapper(farmerToken, rewardWrapper);
      assert(wrapperAddress.isContract());
    }
  }

  function nextToken() external override view returns (address) {
    return _nextToken;
  }

  function nextReward() external override view returns (address) {
    return _nextReward;
  }
}
