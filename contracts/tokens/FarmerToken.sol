pragma solidity >=0.6.5 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "./Wrapped777.sol";

contract FarmerToken is Wrapped777 {
  using SafeMath for uint256;
  using SignedSafeMath for int256;

  uint256 public constant SCALE = uint256(10) ** 8;
  uint256 private scaledRewardPerToken = 0;
  uint256 public scaledRemainder = 0;

  mapping(address => int) public rewardOffset;

  function _mint(
    address account,
    uint256 amount,
    bytes memory userData,
    bytes memory operatorData
  ) internal override {
    ERC777WithGranularity._mint(account, amount, userData, operatorData);
    rewardOffset[account] = rewardOffset[account].add(int256(amount.mul(scaledRewardPerToken)));
  }

  function harvest(uint reward) public {
    uint256 scaledReward = reward.mul(SCALE).add(scaledRemainder);

    uint256 supply = totalSupply();
    scaledRewardPerToken = scaledRewardPerToken.add(scaledReward.div(supply));
    scaledRemainder = scaledReward.mod(supply);
  }

  function rewardBalance(address user) public view returns (uint256) {
    return scaledRewardBalance(user).div(SCALE);
  }

  function scaledRewardBalance(address user) private view returns (uint256) {
    return uint256(int256(scaledRewardPerToken.mul(balanceOf(user))).sub(rewardOffset[user]));
  }

  function _move(
    address operator,
    address from,
    address to,
    uint256 amount,
    bytes memory userData,
    bytes memory operatorData
  ) internal override {
    int256 scaledRewardToTransfer = int256(scaledRewardBalance(from).mul(amount).div(balanceOf(from)));
    int256 offset = scaledRewardToTransfer.sub(int256(amount.mul(scaledRewardPerToken)));

    ERC777WithGranularity._move(operator, from, to, amount, userData, operatorData);

    rewardOffset[from] = rewardOffset[from].add(offset);
    rewardOffset[to] = rewardOffset[to].sub(offset);
  }

  function withdraw(uint amount) public {
    require(amount <= rewardBalance(msg.sender), "Insuficent reward balance");
    uint256 scaledAmount = amount.mul(SCALE);

    rewardOffset[msg.sender] = rewardOffset[msg.sender].add(int256(scaledAmount));
  }

  function _burn(
    address from,
    uint256 amount,
    bytes memory data,
    bytes memory operatorData
  ) internal override {
    uint rewardToRedistribute = rewardBalance(from).mul(amount).div(balanceOf(from));

    ERC777WithGranularity._burn(from, amount, data, operatorData);

    rewardOffset[from] = rewardOffset[from].sub(int256(amount.mul(scaledRewardPerToken)));
    scaledRewardPerToken = scaledRewardPerToken.add(rewardToRedistribute.div(totalSupply()));
  }
}
