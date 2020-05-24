const { getContract, web3, group, getAccounts, str } = require('./test-lib');
const { singletons } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const TestERC20 = getContract('TestERC20');
const TestERC777 = getContract('TestERC777');
const TestUniswapRouter = getContract('TestUniswapRouter');
const UniswapPoolTogether = getContract('UniswapPoolTogether');
const WrapperFactory = getContract('WrapperFactory');
const Wrapped777 = getContract('Wrapped777');

const { toWei, toBN } = web3.utils;

const ONE_GWEI = 1000000000;

group('PoolTogether - Uniswap', (accounts) => {
  const [defaultSender, user] = getAccounts(accounts);

  before(() => singletons.ERC1820Registry(defaultSender));

  it('Should swap Dai/plDai & USDC/plUSDC', async () => {
    const dai = await TestERC20.new();
    const usdc = await TestERC20.new();
    const pldai = await TestERC777.new();
    const plusdc = await TestERC777.new();

    const factory = await WrapperFactory.new();

    await factory.create(dai.address);
    const daiwrapperAddress = await factory.getWrapper(dai.address);
    const dai777 = await Wrapped777.at(daiwrapperAddress);
    await dai.approve(dai777.address, toWei('10', 'ether'));
    await dai777.wrap(toWei('10', 'ether'));

    await factory.create(usdc.address);
    const usdcwrapperAddress = await factory.getWrapper(usdc.address);
    const usdc777 = await Wrapped777.at(usdcwrapperAddress);
    await usdc.approve(usdc777.address, toWei('10', 'ether'));
    await usdc777.wrap(toWei('10', 'ether'));

    const uniswapRouter = await TestUniswapRouter.new();
    await pldai.transfer(uniswapRouter.address, toWei('100', 'ether'));
    await plusdc.transfer(uniswapRouter.address, toWei('100', 'ether'));

    const pooltogether = await UniswapPoolTogether.new(uniswapRouter.address);
    await pooltogether.addPool(dai777.address, pldai.address);
    await pooltogether.addPool(usdc777.address, plusdc.address);

    await dai777.transfer(user, toWei('10', 'ether'));
    await usdc777.transfer(user, toWei('10', 'ether'));

    // Test Dai pool
    await dai777.transfer(pooltogether.address, toWei('10', 'ether'), { from: user });
    expect(await str(pldai.balanceOf(user))).to.equal(toWei('10', 'ether'));

    await pldai.transfer(pooltogether.address, toWei('10', 'ether'), { from: user });
    expect(await str(dai777.balanceOf(user))).to.equal(toWei('10', 'ether'));

    // Test USDC pool
    await usdc777.transfer(pooltogether.address, toWei('10', 'ether'), { from: user });
    expect(await str(plusdc.balanceOf(user))).to.equal(toWei('10', 'ether'));

    await plusdc.transfer(pooltogether.address, toWei('10', 'ether'), { from: user });
    expect(await str(usdc777.balanceOf(user))).to.equal(toWei('10', 'ether'));
  });
});
