const { getContract, web3, group, getAccounts, str, getDefiAddresses, eth } = require('./test-lib');
const { singletons } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const CurveAdapter = getContract('CurveAdapter');
const CurveExitAdapter = getContract('CurveExitAdapter');
const CRVFarmerFactory = getContract('CRVFarmerFactory');
const CRVFarmerToken = getContract('CRVFarmerToken');
const WrapperFactory = getContract('WrapperFactory');
const Wrapped777 = getContract('Wrapped777');
const TestCurvePool = getContract('TestCurvePool');
const IERC20 = getContract('IERC20');
const YieldAdapterFactory = getContract('YieldAdapterFactory');
const TestCurveGague = getContract('TestCurveGague');
const TestCurveMinter = getContract('TestCurveMinter');
const TestERC20 = getContract('TestERC20');

const ONE_GWEI = 1000000000;
const { toBN } = web3.utils;

group('Curve pools', (accounts) => {
  const [defaultSender, user] = getAccounts(accounts);

  before(() => singletons.ERC1820Registry(defaultSender));

  it('should join a curve pool', async () => {
    const wrapperFactory = await WrapperFactory.new();
    const [token1, token2, token3] = await Promise.all([TestERC20.new(), TestERC20.new(), TestERC20.new()]);

    const curvePool = await TestCurvePool.new([token1.address, token2.address, token3.address]);

    await wrapperFactory.createWrapper(token1.address);
    const token1WrapperAddress = await wrapperFactory.calculateWrapperAddress(token1.address);
    const token1Wrapper = await Wrapped777.at(token1WrapperAddress);

    await wrapperFactory.createWrapper(curvePool.address);
    const curvePoolWrapperAddress = await wrapperFactory.calculateWrapperAddress(curvePool.address);
    const curvePoolWrapper = await Wrapped777.at(curvePoolWrapperAddress);

    const adapter = await CurveAdapter.new(curvePoolWrapperAddress, 3);

    token1.approve(token1WrapperAddress, eth(1));
    await token1Wrapper.wrapTo(eth(1), user);

    await token1Wrapper.transfer(adapter.address, eth(1), { from: user });

    expect(await str(curvePoolWrapper.balanceOf(user))).to.equal(eth(1));

    // Exit
    const exitAdapter = await CurveExitAdapter.new(token1WrapperAddress);

    await curvePoolWrapper.transfer(exitAdapter.address, eth(1), { from: user });
    expect(await str(token1Wrapper.balanceOf(user))).to.equal(eth(1));
  });

  it('should use CRV farmer tokens', async function() {
    this.timeout(5000);

    const [token1, token2, token3] = await Promise.all([TestERC20.new(), TestERC20.new(), TestERC20.new()]);
    const curvePool = await TestCurvePool.new([token1.address, token2.address, token3.address]);

    const gague = await TestCurveGague.new(curvePool.address);
    const minter = await TestCurveMinter.new();
    const crv = await minter.token();

    const wrapperFactory = await WrapperFactory.new();
    const adapterFactory = await YieldAdapterFactory.new(wrapperFactory.address);
    const farmerFactory = await CRVFarmerFactory.new(crv, adapterFactory.address);

    await wrapperFactory.createWrapper(crv);
    const crvWrapperAddress = await wrapperFactory.calculateWrapperAddress(crv);
    const crvWrapper = await Wrapped777.at(crvWrapperAddress);

    await wrapperFactory.createWrapper(token1.address);
    const token1WrapperAddress = await wrapperFactory.calculateWrapperAddress(token1.address);
    const token1Wrapper = await Wrapped777.at(token1WrapperAddress);

    await farmerFactory.createWrapper(curvePool.address, gague.address);
    const poolWrapperAddress = await farmerFactory.calculateWrapperAddress(curvePool.address, gague.address);
    const poolWrapper = await CRVFarmerToken.at(poolWrapperAddress);

    const adapter = await CurveAdapter.new(poolWrapperAddress, 3);

    token1.approve(token1WrapperAddress, eth(1));
    await token1Wrapper.wrapTo(eth(1), user);

    await token1Wrapper.transfer(adapter.address, eth(1), { from: user });

    expect(await str(poolWrapper.balanceOf(user))).to.equal(eth(1));
    expect(await str(gague.balance(poolWrapperAddress))).to.equal(eth(1));

    // Farm
    await poolWrapper.farm(minter.address);
    expect(await str(poolWrapper.rewardBalance(crv, user))).to.equal(eth(1));

    // Exit
    const exitAdapter = await CurveExitAdapter.new(token1WrapperAddress);

    await poolWrapper.transfer(exitAdapter.address, eth(1), { from: user });
    expect(await str(token1Wrapper.balanceOf(user))).to.equal(eth(1));
    expect(await str(crvWrapper.balanceOf(user))).to.equal(eth(1));
  });
});
