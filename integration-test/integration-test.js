global.artifacts = artifacts;
global.web3 = web3;

const runBalancerTest = require('./balancer-pools');
const { DAI, BAL, UNISWAP_ROUTER } = require('./constants');

const WrapperFactory = artifacts.require('WrapperFactory');
const Wrapped777 = artifacts.require('Wrapped777');
const UniswapWrapper = artifacts.require('UniswapWrapper');
const UniswapWrapperFactory = artifacts.require('UniswapWrapperFactory');


module.exports = function(callback) {
  run().then(callback).catch(callback);
}

const { toWei } = web3.utils;

async function createWrapper(wrapperFactory, address) {
  const [wrapperAddress] = await Promise.all([
    wrapperFactory.calculateWrapperAddress(address),
    wrapperFactory.createWrapper(address),
  ]);
  const wrapper = await Wrapped777.at(wrapperAddress);
  return wrapper;
}

async function createUniswapAndSwapETH(uniswapFactory, wrapper, eth) {
  const [exchangeAddress] = await Promise.all([
    uniswapFactory.calculateExchangeAddress(wrapper),
    uniswapFactory.createExchange(wrapper),
  ]);
  const exchange = await UniswapWrapper.at(exchangeAddress);
  await exchange.sendTransaction({ value: toWei(eth, 'ether') });

  return exchange;
}

async function run() {
  const [defaultAccount, user] = await web3.eth.getAccounts();

  const wrapperFactory = await WrapperFactory.new();

  const [daiWrapper, balWrapper] = await Promise.all([
    createWrapper(wrapperFactory, DAI),
    createWrapper(wrapperFactory, BAL),
  ]);

  // Uniswap

  const uniswapFactory = await UniswapWrapperFactory.new(UNISWAP_ROUTER);

  await Promise.all([
    createUniswapAndSwapETH(uniswapFactory, daiWrapper.address, '1'),
    createUniswapAndSwapETH(uniswapFactory, balWrapper.address, '0.1'),
  ]);

  await daiWrapper.transfer(daiWrapper.address, toWei('10', 'ether'));

  console.log('Dai777 balance', await daiWrapper.balanceOf(defaultAccount));
  console.log('BAL777 balance', await daiWrapper.balanceOf(defaultAccount));

  await runBalancerTest(wrapperFactory);
}
