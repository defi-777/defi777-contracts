pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./YieldAdapter.sol";
import "./IYieldAdapterFactory.sol";


contract YieldAdapterFactory is Ownable, IYieldAdapterFactory {
  using Address for address;

  address private _nextToken;
  address private _nextReward;
  address private factory;

  bytes32 public constant ADAPTER_HASH = keccak256(type(YieldAdapter).creationCode);

  event WrapperCreated(address farmerToken, address rewardToken);

  constructor(address _factory) public {
    factory = _factory;
  }

  function calculateWrapperAddress(address farmerToken, address rewardToken) external view override returns (address calculatedAddress) {
    calculatedAddress = _calculateWrapperAddress(farmerToken, rewardToken);
  }

  function _calculateWrapperAddress(address farmerToken, address rewardToken) private view returns (address calculatedAddress) {
    calculatedAddress = address(uint(keccak256(abi.encodePacked(
      byte(0xff),
      address(this),
      keccak256(abi.encodePacked(farmerToken, rewardToken)),
      ADAPTER_HASH
    ))));
  }

  function createWrapper(address farmerToken, address rewardToken) public {
    _nextToken = farmerToken;
    _nextReward = rewardToken;
    new YieldAdapter{salt: keccak256(abi.encodePacked(farmerToken, rewardToken))}();
    _nextToken = address(0);
    _nextReward = address(0);

    emit WrapperCreated(farmerToken, rewardToken);
  }

  function getWrapperAddress(address farmerToken, address rewardToken) external override returns (address wrapperAddress) {
    wrapperAddress = _calculateWrapperAddress(farmerToken, rewardToken);

    if(!wrapperAddress.isContract()) {
      createWrapper(farmerToken, rewardToken);
      assert(wrapperAddress.isContract());
    }
  }

  function nextToken() external override view returns (address) {
    return _nextToken;
  }

  function nextReward() external override view returns (address) {
    return _nextReward;
  }

  function wrapperFactory() external override view returns (address) {
    return factory;
  }

  function setWrapperFactory(address _factory) external onlyOwner {
    factory = _factory;
  }
}
