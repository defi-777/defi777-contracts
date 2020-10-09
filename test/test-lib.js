let getContract, _web3, group;
let getAccounts = (accounts) => accounts;

const str = promise => promise.then(result => result.toString())

if (global.artifacts) {
  getContract = artifacts.require.bind(artifacts);
  group = contract;
  _web3 = web3;

} else {
  const { accounts, defaultSender, contract, web3 } = require('@openzeppelin/test-environment');
  getContract = contract.fromArtifact.bind(contract);
  _web3 = web3;
  group = describe;
  getAccounts = () => [defaultSender, ...accounts];
}

const getDefiAddresses = async () => {
  const [weth, dai, aave] = await Promise.all([
    getContract('WETH').new(),
    getContract('TestDai').new(),
    getContract('TestAaveLendingPoolAddressProvider').new(),
  ]);
  return {
    weth: weth.address,
    dai: dai.address,
    aave: aave.address,
  };
};

const getWrappedToken = async (tokenContract) => {
  const _tokenContract = tokenContract || getContract('TestERC20');
  const WrapperFactory = getContract('WrapperFactory');
  const Wrapped777 = getContract('Wrapped777');

  const [token, factory] = await Promise.all([
    _tokenContract.new(),
    WrapperFactory.new(),
  ]);

  const [_, wrapperAddress] = await Promise.all([
    factory.createWrapper(token.address),
    factory.calculateWrapperAddress(token.address),
  ]);

  const wrapper = await Wrapped777.at(wrapperAddress);
  await token.approve(wrapperAddress, _web3.utils.toWei('100', 'ether'));
  await wrapper.wrap(_web3.utils.toWei('100', 'ether'));

  return [wrapper, token];
}

module.exports = {
  getContract,
  web3: _web3,
  getAccounts,
  group,
  str,
  getDefiAddresses,
  getWrappedToken,
  eth: num => _web3.utils.toWei(num.toString(), 'ether'),
};
