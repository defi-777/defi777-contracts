const { getContract, web3, group, getAccounts, str, eth } = require('./test-lib');
const { singletons } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const CurveAdapter = getContract('CurveAdapter');
const CurveExitAdapter = getContract('CurveExitAdapter');
const WrapperFactory = getContract('WrapperFactory');
const Wrapped777 = getContract('Wrapped777');
const TestCurvePool = getContract('TestCurvePool');
const TestERC20 = getContract('TestERC20');


group('Curve pools', (accounts) => {
  const [defaultSender, user] = getAccounts(accounts);

  before(() => singletons.ERC1820Registry(defaultSender));

  it('should join a curve pool', async () => {
    const wrapperFactory = await WrapperFactory.new();

    const token1 = await TestERC20.new();
    const token2 = await TestERC20.new();
    const token3 = await TestERC20.new();

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
});
