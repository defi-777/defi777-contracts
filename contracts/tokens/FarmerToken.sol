pragma solidity >=0.6.5 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";

contract FarmerToken {
  using SafeMath for uint256;
  using SignedSafeMath for int256;

  uint totalSupply = 0;
  mapping(address => uint) public balance;

  uint scaledRewardPerToken = 0;

  uint256 public constant SCALE = uint256(10) ** 8;
  uint256 public scaledRemainder = 0;

  mapping(address => int) public rewardOffset;

  function mint(uint tokens) public {
    totalSupply = totalSupply.add(tokens);
    balance[msg.sender] = balance[msg.sender].add(tokens);
    rewardOffset[msg.sender] = rewardOffset[msg.sender].add(int256(tokens.mul(scaledRewardPerToken)));
  }

  function harvest(uint reward) public {
    uint256 scaledReward = reward.mul(SCALE).add(scaledRemainder);

    scaledRewardPerToken = scaledRewardPerToken.add(scaledReward.div(totalSupply));
    scaledRemainder = scaledReward.mod(totalSupply);
  }

  function rewardBalance(address user) public view returns (uint256) {
    return scaledRewardBalance(user).div(SCALE);
  }

  function scaledRewardBalance(address user) private view returns (uint256) {
    return uint256(int256(scaledRewardPerToken.mul(balance[user])).sub(rewardOffset[user]));
  }

  function transfer(address to, uint amount) public {
    int256 scaledRewardToTransfer = int256(scaledRewardBalance(msg.sender).mul(amount).div(balance[msg.sender]));
    int256 offset = scaledRewardToTransfer.sub(int256(amount.mul(scaledRewardPerToken)));

    balance[msg.sender] = balance[msg.sender].sub(amount);
    balance[to] = balance[to].add(amount);

    rewardOffset[msg.sender] = rewardOffset[msg.sender].add(offset);
    rewardOffset[to] = rewardOffset[to].sub(offset);
  }

  function withdraw(uint amount) public {
    require(amount <= rewardBalance(msg.sender), "Insuficent reward balance");
    uint256 scaledAmount = amount.mul(SCALE);

    rewardOffset[msg.sender] = rewardOffset[msg.sender].add(int256(scaledAmount));
  }

  function burn(uint tokens) public {
    require(tokens <= balance[msg.sender]);

    balance[msg.sender] -= tokens;
    totalSupply -= tokens;

    rewardOffset[msg.sender] -= int256(tokens * scaledRewardPerToken);

    uint rewardToRedistribute = rewardBalance(msg.sender) * tokens / balance[msg.sender];
    scaledRewardPerToken += rewardToRedistribute / totalSupply;
  }
}
