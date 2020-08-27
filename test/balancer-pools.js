const { getContract, web3, group, getAccounts, str, getDefiAddresses, eth } = require('./test-lib');
const { singletons } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const BalancerPool = getContract('BalancerPool');
const BalancerPoolFactory = getContract('BalancerPoolFactory');
const WrapperFactory = getContract('WrapperFactory');
const Wrapped777 = getContract('Wrapped777');
const TestBPool = getContract('TestBPool');
const IERC20 = getContract('IERC20');


group('Balancer Pools', (accounts) => {
  const [defaultSender, user] = getAccounts(accounts);

  let weth, dai;

  before(async function () {
    this.timeout(3000);

    await singletons.ERC1820Registry(defaultSender);
    ({ weth, dai } = await getDefiAddresses());
  });

  it('should join a balancer pool with ETH', async () => {
    const wrapperFactory = await WrapperFactory.new();
    const poolFactory = await BalancerPoolFactory.new(weth);

    const bpool = await TestBPool.new([weth, dai]);

    await wrapperFactory.createWrapper(bpool.address);
    const poolWrapperAddress = await wrapperFactory.calculateWrapperAddress(bpool.address);
    const poolWrapper = await Wrapped777.at(poolWrapperAddress);

    await poolFactory.createWrapper(poolWrapperAddress);
    const poolAdapter = await BalancerPool.at(await poolFactory.calculateWrapperAddress(poolWrapperAddress));

    await poolAdapter.sendTransaction({ value: eth(1), from: user });

    expect(await str(poolWrapper.balanceOf(user))).to.equal(eth(1));
  });

  it('should join a balancer pool with Dai777', async () => {
    const wrapperFactory = await WrapperFactory.new();
    const poolFactory = await BalancerPoolFactory.new(weth);

    const bpool = await TestBPool.new([weth, dai]);

    await wrapperFactory.createWrapper(bpool.address);
    const poolWrapperAddress = await wrapperFactory.calculateWrapperAddress(bpool.address);
    const poolWrapper = await Wrapped777.at(poolWrapperAddress);

    const daiWrapperAddress = await wrapperFactory.calculateWrapperAddress(dai);
    await wrapperFactory.createWrapper(dai);
    const daiWrapper = await Wrapped777.at(daiWrapperAddress);
    (await IERC20.at(dai)).approve(daiWrapperAddress, eth(1));
    await daiWrapper.wrapTo(eth(1), user);

    await poolFactory.createWrapper(poolWrapperAddress);
    const poolAdapterAddress = await poolFactory.calculateWrapperAddress(poolWrapperAddress);

    await daiWrapper.transfer(poolAdapterAddress, eth(1), { from: user });

    expect(await str(poolWrapper.balanceOf(user))).to.equal(eth(1));
  });
});
