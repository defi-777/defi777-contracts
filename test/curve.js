const { getContract, web3, group, getAccounts, str, getWrapperFactory, eth } = require('./test-lib');
const { singletons } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const CurveAdapter = getContract('CurveAdapter');
const CurveExitAdapter = getContract('CurveExitAdapter');
const CurveRegistry = getContract('CurveRegistry');
const CRVFarmerTokenFactory = getContract('CRVFarmerTokenFactory');
const CRVFarmerToken = getContract('CRVFarmerToken');
const WrapperFactory = getContract('WrapperFactory');
const Wrapped777 = getContract('Wrapped777');
const IERC20 = getContract('IERC20');
const YieldAdapterFactory = getContract('YieldAdapterFactory');
const MockCurveDeposit = getContract('MockCurveDeposit');
const TestCurveGague = getContract('TestCurveGague');
const TestCurveMinter = getContract('TestCurveMinter');
const TestERC20 = getContract('TestERC20');

const ONE_GWEI = 1000000000;
const { toBN } = web3.utils;

group('Curve pools', (accounts) => {
  const [defaultSender, user] = getAccounts(accounts);

  before(() => singletons.ERC1820Registry(defaultSender));

  it('should join a curve pool', async () => {
    const [token1, token2, token3] = await Promise.all([TestERC20.new(), TestERC20.new(), TestERC20.new()]);

    const registry = await CurveRegistry.new();

    const curveDeposit = await MockCurveDeposit.new([token1.address, token2.address, token3.address]);
    const lpToken = await curveDeposit.token();
    
    await registry.addDepositor(curveDeposit.address);
    const registryInfo = await registry.getDepositor(lpToken, token2.address);
    expect(registryInfo[0]).to.equal(curveDeposit.address);
    expect(registryInfo[1].toNumber()).to.equal(3);
    expect(registryInfo[2].toNumber()).to.equal(1);

    const { getWrappers } = await getWrapperFactory();
    const [token1Wrapper, lpTokenWrapper] = await getWrappers([token1, lpToken]);

    const adapter = await CurveAdapter.new(lpTokenWrapper.address, registry.address);

    await token1.approve(token1Wrapper.address, eth(1));
    await token1Wrapper.wrapTo(eth(1), user);

    await token1Wrapper.transfer(adapter.address, eth(1), { from: user });

    expect(await str(lpTokenWrapper.balanceOf(user))).to.equal(eth(1));

    // Exit
    const exitAdapter = await CurveExitAdapter.new(token1Wrapper.address, registry.address);

    await lpTokenWrapper.transfer(exitAdapter.address, eth(1), { from: user });
    expect(await str(token1Wrapper.balanceOf(user))).to.equal(eth(1));
  });

  it('should use CRV farmer tokens', async function() {
    this.timeout(5000);

    const [token1, token2, token3] = await Promise.all([TestERC20.new(), TestERC20.new(), TestERC20.new()]);

    const registry = await CurveRegistry.new();

    const curveDeposit = await MockCurveDeposit.new([token1.address, token2.address, token3.address]);
    const lpToken = await curveDeposit.token();
    await registry.addDepositor(curveDeposit.address);

    const gague = await TestCurveGague.new(lpToken);
    const minter = await TestCurveMinter.new();
    const crv = await minter.token();

    const adapterFactory = await YieldAdapterFactory.new();

    const { getWrappers } = await getWrapperFactory();
    const [crvWrapper, token1Wrapper] = await getWrappers([crv, token1])

    const farmerFactory = await CRVFarmerTokenFactory.new(crvWrapper.address, adapterFactory.address);

    await farmerFactory.createWrapper(lpToken, gague.address);
    const lpTokenWrapperAddress = await farmerFactory.calculateWrapperAddress(lpToken, gague.address);
    const lpTokenWrapper = await CRVFarmerToken.at(lpTokenWrapperAddress);

    const adapter = await CurveAdapter.new(lpTokenWrapperAddress, registry.address);

    token1.approve(token1Wrapper.address, eth(1));
    await token1Wrapper.wrapTo(eth(1), user);

    await token1Wrapper.transfer(adapter.address, eth(1), { from: user });

    expect(await str(lpTokenWrapper.balanceOf(user))).to.equal(eth(1));
    expect(await str(gague.balance(lpTokenWrapperAddress))).to.equal(eth(1));

    // Farm
    await lpTokenWrapper.farm(minter.address);
    expect(await str(lpTokenWrapper.rewardBalance(crv, user))).to.equal(eth(1));

    // Exit
    const exitAdapter = await CurveExitAdapter.new(token1Wrapper.address, registry.address);

    await lpTokenWrapper.transfer(exitAdapter.address, eth(1), { from: user });
    expect(await str(token1Wrapper.balanceOf(user))).to.equal(eth(1));
    expect(await str(crvWrapper.balanceOf(user))).to.equal(eth(1));
  });
});
