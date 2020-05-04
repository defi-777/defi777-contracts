const { getContract, web3, group, getAccounts, str, getDefiAddresses } = require('./test-lib');
const { singletons } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const BalancerHub = getContract('BalancerHub');
const IERC20 = getContract('IERC20');
const WrapperFactory = getContract('WrapperFactory');
const Wrapped777 = getContract('Wrapped777');
const TestBFactory = getContract('TestBFactory');
const TestBPool = getContract('TestBPool');
const TestERC20 = getContract('TestERC20');

const { toWei, toBN } = web3.utils;

const ONE_GWEI = 1000000000;

group('Balancer', (accounts) => {
  const [defaultSender, user] = getAccounts(accounts);

  before(() => singletons.ERC1820Registry(defaultSender));

  it('should swap tokens through a balancer', async () => {
    const factory = await WrapperFactory.new();

    const token1 = await TestERC20.new();
    const token2 = await TestERC20.new();

    await factory.create(token1.address);
    await factory.create(token2.address);
    const wrapper1Address = await factory.getWrapper(token1.address);
    const wrapper2Address = await factory.getWrapper(token2.address);
    const wrapper1 = await Wrapped777.at(wrapper1Address);
    const wrapper2 = await Wrapped777.at(wrapper2Address);

    await token2.approve(wrapper2Address, toWei('10', 'ether'));
    await wrapper2.wrap(toWei('10', 'ether'));
    await wrapper2.transfer(user, toWei('5', 'ether'));

    const bfactory = await TestBFactory.new();
    const bpool = await TestBPool.new([token1.address, token2.address]);
    await token1.transfer(bpool.address, toWei('10', 'ether'));

    const hub = await BalancerHub.new(bfactory.address);
    await hub.addPool(bpool.address);
    expect(await hub.getBestPool(token1.address, token2.address)).to.equal(bpool.address);
    expect(await hub.getBestPool(token2.address, token1.address)).to.equal(bpool.address);

    const targetContract = await hub.calculateAddress(token1.address);

    await wrapper2.transfer(targetContract, toWei('2', 'ether'), { from: user });
    expect(await str(wrapper1.balanceOf(user))).to.equal(toWei('2', 'ether'));
  });
});
