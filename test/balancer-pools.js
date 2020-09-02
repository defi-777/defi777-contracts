const { getContract, web3, group, getAccounts, str, getDefiAddresses, eth } = require('./test-lib');
const { singletons } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const BalancerPool = getContract('BalancerPool');
const BalancerPoolFactory = getContract('BalancerPoolFactory');
const BalancerPoolExitFactory = getContract('BalancerPoolExitFactory');
const FarmerToken = getContract('FarmerToken');
const FarmerTokenFactory = getContract('FarmerTokenFactory');
const WrapperFactory = getContract('WrapperFactory');
const Wrapped777 = getContract('Wrapped777');
const TestBPool = getContract('TestBPool');
const IERC20 = getContract('IERC20');
const YieldAdapterFactory = getContract('YieldAdapterFactory');

const ONE_GWEI = 1000000000;
const { toBN } = web3.utils;

group('Balancer Pools', (accounts) => {
  const [defaultSender, user] = getAccounts(accounts);

  let weth, dai;

  before(async function () {
    this.timeout(3000);

    await singletons.ERC1820Registry(defaultSender);
    ({ weth, dai } = await getDefiAddresses());
  });

  it('should join and exit a balancer pool with ETH', async () => {
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

    // Exit
    const exitFactory = await BalancerPoolExitFactory.new(weth);

    await exitFactory.createWrapper('0x0000000000000000000000000000000000000000');
    const exitAdapter = await exitFactory.calculateWrapperAddress('0x0000000000000000000000000000000000000000');

    const startingBalance = await web3.eth.getBalance(user);
    const { receipt } = await poolWrapper.transfer(exitAdapter, eth(1), { gasPrice: ONE_GWEI, from: user });

    const ethSpentOnGas = ONE_GWEI * receipt.gasUsed;
    expect(await web3.eth.getBalance(user))
      .to.equal((toBN(startingBalance).add(toBN(eth(1))).sub(toBN(ethSpentOnGas))).toString());
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

    // Exit
    const exitFactory = await BalancerPoolExitFactory.new(weth);

    await exitFactory.createWrapper(daiWrapperAddress);
    const exitAdapter = await exitFactory.calculateWrapperAddress(daiWrapperAddress);

    await poolWrapper.transfer(exitAdapter, eth(1), { from: user });
    expect(await str(daiWrapper.balanceOf(user))).to.equal(eth(1));
  });

  it('should farm tokens when exiting a pool', async () => {
    const wrapperFactory = await WrapperFactory.new();
    const adapterFactory = await YieldAdapterFactory.new(wrapperFactory.address);
    const farmerFactory = await FarmerTokenFactory.new(adapterFactory.address);
    const poolFactory = await BalancerPoolFactory.new(weth);

    const bpool = await TestBPool.new([weth]);

    await wrapperFactory.createWrapper(dai);
    const daiWrapper = await Wrapped777.at(await wrapperFactory.calculateWrapperAddress(dai));

    await farmerFactory.createWrapper(bpool.address, [dai]);
    const poolWrapperAddress = await farmerFactory.calculateWrapperAddress(bpool.address, [dai]);
    const poolWrapper = await FarmerToken.at(poolWrapperAddress);

    await poolFactory.createWrapper(poolWrapperAddress);
    const poolAdapter = await BalancerPool.at(await poolFactory.calculateWrapperAddress(poolWrapperAddress));

    await poolAdapter.sendTransaction({ value: eth(1), from: user });

    // Farm
    const daiToken = await IERC20.at(dai);
    await daiToken.transfer(poolWrapperAddress, eth(1));
    await poolWrapper.harvest(dai);

    const daiAdapter = await IERC20.at(await poolWrapper.getRewardAdapter(dai));
    expect(await str(daiAdapter.balanceOf(user))).to.equal(eth(1));

    // Exit
    const exitFactory = await BalancerPoolExitFactory.new(weth);

    await exitFactory.createWrapper('0x0000000000000000000000000000000000000000');
    const exitAdapter = await exitFactory.calculateWrapperAddress('0x0000000000000000000000000000000000000000');

    const startingBalance = await web3.eth.getBalance(user);
    const { receipt } = await poolWrapper.transfer(exitAdapter, eth(1), { gasPrice: ONE_GWEI, from: user });

    expect(await str(daiWrapper.balanceOf(user))).to.equal(eth(1));

    // Check ETH balance
    const ethSpentOnGas = ONE_GWEI * receipt.gasUsed;
    expect(await web3.eth.getBalance(user))
      .to.equal((toBN(startingBalance).add(toBN(eth(1))).sub(toBN(ethSpentOnGas))).toString());
  });
});
