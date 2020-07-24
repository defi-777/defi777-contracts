pragma solidity >=0.6.2 <0.7.0;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/ISynthetix.sol";
import "../interfaces/ISynth.sol";
import "./TestSynth.sol";

contract TestSynthetix is ISynthetix {

  mapping(bytes32 => ISynth) private keyToSynth;
  mapping(address => bytes32) private synthToKey;
  mapping(bytes32 => uint256) private synthPrice;

  constructor() public {
    makeSynth("sUSD", 1);
    makeSynth("sBTC", 2);
  }

  function makeSynth(string memory symbol, uint256 price) private {
    TestSynth synth = new TestSynth(symbol);
    bytes32 key = stringToBytes32(symbol);
    keyToSynth[key] = ISynth(synth);
    synthToKey[address(synth)] = key;
    synthPrice[key] = price;
  }

  function synths(bytes32 currencyKey) external view override returns (ISynth) {
    return keyToSynth[currencyKey];
  }

  function synthsByAddress(address synthAddress) external view override returns (bytes32) {
    return synthToKey[synthAddress];
  }

  function exchange(
      bytes32 sourceCurrencyKey,
      uint sourceAmount,
      bytes32 destinationCurrencyKey
  ) external override returns (uint amountReceived) {
    keyToSynth[sourceCurrencyKey].burn(msg.sender, sourceAmount);
    amountReceived = sourceAmount * synthPrice[sourceCurrencyKey] / synthPrice[destinationCurrencyKey];
    keyToSynth[destinationCurrencyKey].issue(msg.sender, amountReceived);
  }

  function stringToBytes32(string memory source) private pure returns (bytes32 result) {
    bytes memory tempEmptyStringTest = bytes(source);
    if (tempEmptyStringTest.length == 0) {
        return 0x0;
    }

    assembly {
        result := mload(add(source, 32))
    }
  }
}
