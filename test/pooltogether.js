const { getContract, web3, group, getAccounts, str } = require('./test-lib');
const { singletons } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const TestERC20 = getContract('TestERC20');
const TestPoolTogetherPool = getContract('TestPoolTogetherPool');
const WrapperFactory = getContract('WrapperFactory');
const Wrapped777 = getContract('Wrapped777');
const PoolTogether777 = getContract('PoolTogether777');

const { toWei, toBN } = web3.utils;

const ONE_GWEI = 1000000000;

group('PoolTogether', (accounts) => {
  const [defaultSender] = getAccounts(accounts);

  before(() => singletons.ERC1820Registry(defaultSender));

  it('should deposit and withdraw', async () => {
    const token = await TestERC20.new();
    const factory = await WrapperFactory.new();

    await factory.create(token.address);
    const wrapperAddress = await factory.getWrapper(token.address);
    const wrapper = await Wrapped777.at(wrapperAddress);
    await token.approve(wrapperAddress, toWei('10', 'ether'));
    await wrapper.wrap(toWei('10', 'ether'));

    const pool = await TestPoolTogetherPool.new(token.address);
    const poolTokenAddress = await pool.poolToken();
    const poolToken = await TestERC20.at(poolTokenAddress);

    const pooltogether = await PoolTogether777.new();
    await pooltogether.addPool(pool.address, wrapperAddress);

    await wrapper.transfer(pooltogether.address, toWei('1'));

    expect(await str(poolToken.balanceOf(defaultSender))).to.equal(toWei('1', 'ether'));

    await poolToken.transfer(pooltogether.address, toWei('1', 'ether'));
    expect(await str(wrapper.balanceOf(defaultSender))).to.equal(toWei('10', 'ether'));
  });
});
