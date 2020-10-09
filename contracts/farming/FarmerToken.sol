// SPDX-License-Identifier: MIT
pragma solidity >=0.6.5 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../tokens/AddressBook.sol";
import "../tokens/Wrapped777.sol";
import "./IFarmerToken.sol";
import "./IFarmerTokenFactory.sol";
import "./IYieldAdapterFactory.sol";

contract FarmerToken is Wrapped777, IFarmerToken {
  using SafeMath for uint256;
  using SignedSafeMath for int256;

  uint256 private constant SCALE = uint256(10) ** 8;

  address[] private _rewardTokens;
  address[] private _rewardWrappers;
  mapping(address => uint256) private scaledRewardPerToken;
  mapping(address => uint256) private scaledRemainder;
  mapping(address => uint256) private totalRewardBalance;

  mapping(address => mapping(address => int256)) private rewardOffset;

  IYieldAdapterFactory private immutable adapterFactory;

  constructor() public {
    address yieldAdapterFactory;
    address[] memory rewardWrappers;
    (yieldAdapterFactory, rewardWrappers) = IFarmerTokenFactory(msg.sender).yieldAdapterFactoryAndRewards();

    IYieldAdapterFactory _adapterFactory = IYieldAdapterFactory(yieldAdapterFactory);
    adapterFactory = _adapterFactory;

    _rewardWrappers = rewardWrappers;
    for (uint8 i = 0; i < rewardWrappers.length; i++) {
      address wrapper = rewardWrappers[i];
      address token = address(Wrapped777(wrapper).token());
      _rewardTokens.push(token);

      _adapterFactory.createWrapper(address(this), rewardWrappers[i]);
    }

    ERC1820_REGISTRY.setInterfaceImplementer(address(this), keccak256("Farmer777"), address(this));
  }

  /**
   * @return List of ERC20 token addresses handled by the contract
   */
  function rewardTokens() external view override returns (address[] memory) {
    return _rewardTokens;
  }

  /**
   * @return List of ERC777 wrappers for the reward tokens
   */
  function rewardWrappers() external view override returns (address[] memory) {
    return _rewardWrappers;
  }

  function getRewardAdapter(address rewardWrapper) external view override returns (address) {
    return adapterFactory.calculateWrapperAddress(address(this), rewardWrapper);
  }

  function _mint(
    address account,
    uint256 amount,
    bytes memory userData,
    bytes memory operatorData
  ) internal override {
    preMint(amount);

    ERC777WithGranularity._mint(account, amount, userData, operatorData);

    for (uint i = 0; i < _rewardTokens.length; i++) {
      address token = _rewardTokens[i];
      int256 baseOffset = int256(amount.mul(scaledRewardPerToken[token]));
      rewardOffset[token][account] = rewardOffset[token][account].add(baseOffset);
    }
  }

  /**
   * @dev Read the balance of a reward token and credit all token holders' reward balance.
   *
   * @param token Address of an ERC20 reward token contract
   */
  function harvest(address token) public {
    uint256 newTotal = IERC20(token).balanceOf(address(this));
    uint256 harvestedTokens = newTotal - totalRewardBalance[token];
    totalRewardBalance[token] = newTotal;

    uint256 scaledReward = harvestedTokens.mul(SCALE).add(scaledRemainder[token]);

    uint256 supply = totalSupply();
    scaledRewardPerToken[token] = scaledRewardPerToken[token].add(scaledReward.div(supply));
    scaledRemainder[token] = scaledReward.mod(supply);
  }

  /**
   * @dev Unclaimed balance of a reward token, allocated to a token holder
   *
   * @param token Address of an ERC20 reward token contract
   * @param user Token holder
   */
  function rewardBalance(address token, address user) external view override returns (uint256) {
    return scaledRewardBalance(token, user).div(SCALE);
  }

  function scaledRewardBalance(address token, address user) private view returns (uint256) {
    return uint256(int256(scaledRewardPerToken[token].mul(balanceOf(user))).sub(rewardOffset[token][user]));
  }

  function _move(
    address operator,
    address from,
    address to,
    uint256 amount,
    bytes memory userData,
    bytes memory operatorData
  ) internal override {
    uint256 startBalance = balanceOf(from);

    for (uint i = 0; i < _rewardTokens.length; i++) {
      address token = _rewardTokens[i];

      int256 scaledRewardToTransfer = int256(scaledRewardBalance(token, from).mul(amount).div(startBalance));
      int256 offset = scaledRewardToTransfer.sub(int256(amount.mul(scaledRewardPerToken[token])));

      rewardOffset[token][from] = rewardOffset[token][from].add(offset);
      rewardOffset[token][to] = rewardOffset[token][to].sub(offset);
    }

    ERC777WithGranularity._move(operator, from, to, amount, userData, operatorData);
  }

  /**
   * @dev Withdraws reward tokens allocated to a token holder
   *
   * @param token Address of an ERC20 reward token contract
   * @param amount Amount of tokens to withdraw
   */
  function withdraw(address token, uint amount) external {
    _withdraw(token, msg.sender, msg.sender, amount);
  }

  /**
   * @dev Allows a yieldAdapter to withdraw tokens on a user's behalf
   */
  function withdrawFrom(address token, address from, address wrapper, uint256 amount) external override {
    require(msg.sender == adapterFactory.calculateWrapperAddress(address(this), wrapper));
    _withdraw(token, from, wrapper, amount);
  }

  function _withdraw(address token, address from, address to, uint amount) private {
    uint256 scaledAmount = amount.mul(SCALE);
    require(scaledAmount <= scaledRewardBalance(token, from)/*, "Insuficent reward"*/);

    rewardOffset[token][from] = rewardOffset[token][from].add(int256(scaledAmount));

    totalRewardBalance[token] = totalRewardBalance[token].sub(amount);

    IERC20(token).transfer(to, amount);
  }

  function _burn(
    address from,
    uint256 amount,
    bytes memory data,
    bytes memory operatorData
  ) internal override {
    preBurn(amount);

    uint256 startingBalance = balanceOf(from);
    uint256 newSupply = totalSupply() - amount;

    for (uint i = 0; i < _rewardTokens.length; i++) {
      address token = _rewardTokens[i];

      if (newSupply > 0) {
        uint rewardToRedistribute = scaledRewardBalance(token, from).mul(amount).div(startingBalance);
        scaledRewardPerToken[token] = scaledRewardPerToken[token].add(rewardToRedistribute.div(newSupply));
      } else {
        scaledRewardPerToken[token] = 0;
        totalRewardBalance[token] = 0;
      }
    }

    ERC777WithGranularity._burn(from, amount, data, operatorData);
  }

  function preMint(uint256 amount) internal virtual {}

  function preBurn(uint256 amount) internal virtual {}
}
