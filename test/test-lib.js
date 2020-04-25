let getContract, _web3, group;
let getAccounts = (accounts) => accounts;

const str = promise => promise.then(result => result.toString())

if (global.artifacts) {
  getContract = artifacts.require;
  group = contract;
  _web3 = web3;
} else {
  const { accounts, defaultSender, contract, web3 } = require('@openzeppelin/test-environment');
  getContract = contract.fromArtifact.bind(contract);
  _web3 = web3;
  group = describe;
  getAccounts = () => [defaultSender, ...accounts];
}

module.exports = { getContract, web3: _web3, getAccounts, group, str };
