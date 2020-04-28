pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./VaultBox.sol";

contract Vault {
  using Address for address;

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
      assert(boxAddress.isContract());
    }
  }

  function vaultBalance(ERC20 token, address user) public view returns (uint256) {
    return token.balanceOf(calculateBoxAddress(user));
  }

  function deposit(ERC20 token, address user) internal {
    address userBox = calculateBoxAddress(user);
    uint256 amount = token.balanceOf(address(this));
    token.transfer(userBox, amount);
  }

  function transfer(ERC20 token, address from, address to, uint256 amount) internal {
    VaultBox fromBox = VaultBox(getBoxAddress(from));
    address toBox = calculateBoxAddress(to);

    fromBox.remove(token, amount);
    token.transfer(toBox, amount);
  }

  function withdraw(ERC20 token, address from, uint256 amount) internal {
    VaultBox fromBox = VaultBox(getBoxAddress(from));

    fromBox.remove(token, amount);
    token.transfer(msg.sender, amount);
  }
}
