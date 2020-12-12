// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ICurveDeposit.sol";

contract CurveRegistry is Ownable {
  struct Depositor {
    address contractAddress;
    uint8 numTokens;
    mapping(address => int128) coinToIndex;
  }

  mapping(address => Depositor) private lpTokenToDepositor;
  bool public locked;

  event AdapterRegistered(address adapter, bool isExit);

  function addDepositor(ICurveDeposit depositor, address lpToken) external onlyOwner {
    require(lpTokenToDepositor[lpToken].contractAddress == address(0));
    lpTokenToDepositor[lpToken].contractAddress = address(depositor);

    bool usesUnderlying = depositorUsesUnderlying(depositor);

    for(int128 i = 0; true; i += 1) {
      address coin = getDepositorCoin(depositor, i, usesUnderlying);
      if (coin == address(0)) {
        lpTokenToDepositor[lpToken].numTokens = uint8(i);
        break;
      }

      lpTokenToDepositor[lpToken].coinToIndex[coin] = i + 1;
    }
  }

  function getDepositor(address lpToken, address coin) external view returns (address, uint8, int128) {
    Depositor storage depositor = lpTokenToDepositor[lpToken];

    int128 index = depositor.coinToIndex[coin];
    if (index == 0) {
      revert('UNSUPPORTED');
    }

    return (depositor.contractAddress, depositor.numTokens, index - 1);
  }

  function depositorUsesUnderlying(ICurveDeposit depositor) private view returns (bool) {
    try depositor.underlying_coins(0) {
      return true;
    } catch {
      return false;
    }
  }

  function getDepositorCoin(ICurveDeposit depositor, int128 index, bool usesUnderlying) private view returns (address) {
    if (usesUnderlying) {
      try depositor.underlying_coins(index) returns (address coin) {
        return coin;
      } catch {
        return address(0);
      }
    } else {
      try depositor.coins(index) returns (address coin) {
        return coin;
      } catch {
        return address(0);
      }
    }
  }

  function setLocked(bool _locked) external onlyOwner {
    locked = _locked;
  }

  function registerAdapter(bool isExit) external {
    require(!locked);
    emit AdapterRegistered(msg.sender, isExit);
  }
}
