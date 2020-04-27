pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./VaultBox.sol";

contract Vault is Ownable {
  using Address for address;

  mapping(address => address) private authorized;

  function setAuthorized(address account, address token) external onlyOwner {
    authorized[account] = token;
  }

  function createBox(address user) public {
    new VaultBox{salt: bytes32(bytes20(user))}();
  }

  function calculateBoxAddress(address user) public view returns (address calculatedAddress) {
    calculatedAddress = address(uint(keccak256(abi.encodePacked(
        byte(0xff),
        address(this),
        bytes32(bytes20(user)),
        keccak256(type(VaultBox).creationCode)
    ))));
  }

  function getBoxAddress(address user) public returns (address boxAddress) {
    boxAddress = calculateBoxAddress(user);

    if(!boxAddress.isContract()) {
      createBox(user);
    }

    assert(boxAddress.isContract());
  }

  function balanceOf(address token, address user) external view returns (uint256) {
    return IERC20(token).balanceOf(calculateBoxAddress(user));
  }

  function deposit(address token, address user) external {
    require(authorized[msg.sender] == token);

    address userBox = calculateBoxAddress(user);
    uint256 amount = IERC20(token).balanceOf(address(this));
    IERC20(token).transfer(userBox, amount);
  }

  function transfer(address token, address from, address to, uint256 amount) external {
    require(authorized[msg.sender] == token);

    VaultBox fromBox = VaultBox(getBoxAddress(from));
    address toBox = calculateBoxAddress(to);

    fromBox.remove(token, amount);
    IERC20(token).transfer(toBox, amount);
  }

  function withdraw(address token, address from, uint256 amount) external {
    require(authorized[msg.sender] == token);

    VaultBox fromBox = VaultBox(getBoxAddress(from));

    fromBox.remove(token, amount);
    IERC20(token).transfer(msg.sender, amount);
  }
}
