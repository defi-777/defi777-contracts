let getContract, _web3, group, getDefiAddresses;
let getAccounts = (accounts) => accounts;

const str = promise => promise.then(result => result.toString())

if (global.artifacts) {
  getContract = artifacts.require;
  group = contract;
  _web3 = web3;

  getDefiAddresses = async () => ({
    aave: '0x24a42fD28C976A61Df5D00D0599C34c4f90748c8',
  });
} else {
  const { accounts, defaultSender, contract, web3 } = require('@openzeppelin/test-environment');
  getContract = contract.fromArtifact.bind(contract);
  _web3 = web3;
  group = describe;
  getAccounts = () => [defaultSender, ...accounts];

  getDefiAddresses = async () => {
    const dai = await contract.fromArtifact('TestDai').new();
    const aave = await contract.fromArtifact('TestAaveLendingPoolAddressProvider').new();
    return {
      dai: dai.address,
      aave: aave.address,
    };
  };
}

module.exports = { getContract, web3: _web3, getAccounts, group, str, getDefiAddresses };
