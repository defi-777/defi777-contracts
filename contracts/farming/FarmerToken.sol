pragma solidity >=0.6.5 <0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../tokens/Wrapped777.sol";

contract FarmerToken is Wrapped777 {
  using SafeMath for uint256;
  using SignedSafeMath for int256;

  uint256 public constant SCALE = uint256(10) ** 8;

  address[] public rewardTokens;
  mapping(address => uint256) private scaledRewardPerToken;
  mapping(address => uint256) public scaledRemainder;
  mapping(address => uint256) public totalRewardBalance;

  mapping(address => mapping(address => int256)) public rewardOffset;

  address public owner;

  event RewardTokenAdded(address token);
  event RewardTokenRemoved(address token);

  constructor() public {
    owner = Ownable(msg.sender).owner();
  }

  function transferOwnership(address newOwner) external onlyOwner {
    require(owner == msg.sender);
    owner = newOwner;
  }

  modifier onlyOwner() {
    require(owner == msg.sender, "Not owner");
    _;
  }

  function addRewardToken(address newToken) external onlyOwner {
    for (uint8 i = 0; i < rewardTokens.length; i++) {
      if (rewardTokens[i] == newToken) {
        revert("Token already added");
      }
    }

    rewardTokens.push(newToken);
    emit RewardTokenAdded(newToken);
  }

  function removeRewardToken(address token) external onlyOwner {
    for (uint8 i = 0; i < rewardTokens.length; i++) {
      if (rewardTokens[i] == token) {
        if (i + 1 < rewardTokens.length) {
          rewardTokens[i] = rewardTokens[rewardTokens.length];
        }
        delete rewardTokens[i];
        emit RewardTokenRemoved(token);
        return;
      }
    }
    revert("Token not found");
  }

  function _mint(
    address account,
    uint256 amount,
    bytes memory userData,
    bytes memory operatorData
  ) internal override {
    ERC777WithGranularity._mint(account, amount, userData, operatorData);

    for (uint i = 0; i < rewardTokens.length; i++) {
      address token = rewardTokens[i];
      int256 baseOffset = int256(amount.mul(scaledRewardPerToken[token]));
      rewardOffset[token][account] = rewardOffset[token][account].add(baseOffset);
    }
  }

  function harvest(address token) public {
    uint256 newTotal = IERC20(token).balanceOf(address(this));
    uint256 harvestedTokens = newTotal - totalRewardBalance[token];
    totalRewardBalance[token] = newTotal;

    uint256 scaledReward = harvestedTokens.mul(SCALE).add(scaledRemainder[token]);

    uint256 supply = totalSupply();
    scaledRewardPerToken[token] = scaledRewardPerToken[token].add(scaledReward.div(supply));
    scaledRemainder[token] = scaledReward.mod(supply);
  }

  function rewardBalance(address token, address user) public view returns (uint256) {
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

    for (uint i = 0; i < rewardTokens.length; i++) {
      address token = rewardTokens[i];

      int256 scaledRewardToTransfer = int256(scaledRewardBalance(token, from).mul(amount).div(startBalance));
      int256 offset = scaledRewardToTransfer.sub(int256(amount.mul(scaledRewardPerToken[token])));

      rewardOffset[token][from] = rewardOffset[token][from].add(offset);
      rewardOffset[token][to] = rewardOffset[token][to].sub(offset);
    }

    ERC777WithGranularity._move(operator, from, to, amount, userData, operatorData);
  }

  function withdraw(address token, uint amount) public {
    require(amount <= rewardBalance(token, msg.sender), "Insuficent reward balance");

    uint256 scaledAmount = amount.mul(SCALE);
    rewardOffset[token][msg.sender] = rewardOffset[token][msg.sender].add(int256(scaledAmount));

    totalRewardBalance[token] = totalRewardBalance[token].sub(amount);

    IERC20(token).transfer(msg.sender, amount);
  }

  function _burn(
    address from,
    uint256 amount,
    bytes memory data,
    bytes memory operatorData
  ) internal override {
    uint256 startingBalance = balanceOf(from);
    uint256 newSupply = totalSupply() - amount;

    for (uint i = 0; i < rewardTokens.length; i++) {
      address token = rewardTokens[i];

      uint rewardToRedistribute = scaledRewardBalance(token, from).mul(amount).div(startingBalance);

      rewardOffset[token][from] = rewardOffset[token][from].sub(int256(amount.mul(scaledRewardPerToken[token])));
      scaledRewardPerToken[token] = scaledRewardPerToken[token].add(rewardToRedistribute.div(newSupply));
    }

    ERC777WithGranularity._burn(from, amount, data, operatorData);
  }
}
