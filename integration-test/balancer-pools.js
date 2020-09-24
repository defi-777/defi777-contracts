const { WETH, DAI, ZERO, MKR_WETH_BALANCER_POOL } = require('./constants');
const { str } = require('./lib');
const { toWei } = require('web3-utils');

const FarmerToken = artifacts.require('FarmerToken');
const FarmerTokenFactory = artifacts.require('FarmerTokenFactory');
const BalancerPool = artifacts.require('BalancerPool');
const BalancerPoolFactory = artifacts.require('BalancerPoolFactory');
const BalancerPoolExitFactory = artifacts.require('BalancerPoolExitFactory');
const IERC20 = artifacts.require('IERC20');
const Wrapped777 = artifacts.require('Wrapped777');
const YieldAdapterFactory = artifacts.require('YieldAdapterFactory');

module.exports = async function(wrapperFactory) {
  console.log('[Balancer Pools]')
  const [defaultAccount, user] = await web3.eth.getAccounts();

  // Balance pools
  const [adapterFactory, poolFactory, daiWrapperAddress] = await Promise.all([
    YieldAdapterFactory.new(wrapperFactory.address),
    BalancerPoolFactory.new(WETH),
    wrapperFactory.calculateWrapperAddress(DAI),
  ]);

  const farmerFactory = await FarmerTokenFactory.new(adapterFactory.address);
  const daiWrapper = await Wrapped777.at(daiWrapperAddress);

  await farmerFactory.createWrapper(MKR_WETH_BALANCER_POOL, [DAI]);
  const poolWrapperAddress = await farmerFactory.calculateWrapperAddress(MKR_WETH_BALANCER_POOL, [DAI]);
  const poolWrapper = await FarmerToken.at(poolWrapperAddress);

  await poolFactory.createWrapper(poolWrapperAddress);
  const poolAdapter = await BalancerPool.at(await poolFactory.calculateWrapperAddress(poolWrapperAddress));

  await poolAdapter.sendTransaction({ from: user, value: web3.utils.toWei('1', 'ether') });
  console.log('Pool balance', await str(poolWrapper.balanceOf(user)), 'BPT');

  // Farm
  const daiToken = await IERC20.at(DAI);
  await daiToken.transfer(poolWrapperAddress, web3.utils.toWei('1', 'ether'));
  await poolWrapper.harvest(DAI);

  const daiAdapter = await IERC20.at(await poolWrapper.getRewardAdapter(DAI));
  console.log('Pool reward balance', await str(daiAdapter.balanceOf(user)), 'Dai');

  // Exit
  const exitFactory = await BalancerPoolExitFactory.new(WETH);

  await exitFactory.createWrapper(ZERO);
  const exitAdapter = await exitFactory.calculateWrapperAddress(ZERO);

  const startingBalance = await web3.eth.getBalance(user);
  const { receipt } = await poolWrapper.transfer(exitAdapter, web3.utils.toWei('1', 'ether'), { from: user });
  const endBalance = await web3.eth.getBalance(user);

  console.log('Farmed reward', await str(daiWrapper.balanceOf(user)), 'Dai777');
  console.log('ETH', parseInt(endBalance) - parseInt(startingBalance));
}
