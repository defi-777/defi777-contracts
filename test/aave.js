const { getContract, web3, group, getAccounts, str, eth, getDefiAddresses, getWrapperFactory } = require('./test-lib');
const { singletons } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const IERC20 = getContract('IERC20');
const Wrapped777 = getContract('Wrapped777');
const TestAaveLendingPoolAddressProvider = getContract('TestAaveLendingPoolAddressProvider');
const TestAaveLendingPool = getContract('TestAaveLendingPool');
const AaveAdapter = getContract('AaveAdapter');

const { toBN } = web3.utils;

const ONE_GWEI = 1000000000;

group('Aave', (accounts) => {
  const [defaultSender, user1, user2] = getAccounts(accounts);
  let dai, weth, dai777, aDai, aDai777, aaveAddressProvider, aaveLendingPool;

  before(async function () {
    // this.timeout(3000);

    await singletons.ERC1820Registry(defaultSender);
    ({ dai, weth } = await getDefiAddresses());

    aaveAddressProvider = await TestAaveLendingPoolAddressProvider.new();
    aaveLendingPool = await TestAaveLendingPool.at(await aaveAddressProvider.getLendingPool());

    await aaveLendingPool.createAToken(dai);
    await aaveLendingPool.createAToken(weth);
    aDai = await aaveLendingPool.getAToken(dai);
    aWeth = await aaveLendingPool.getAToken(weth);

    const { getWrappers } = await getWrapperFactory();

    ([dai777, aDai777, aWeth777] = await getWrappers([dai, aDai, aWeth]));

    const daiToken = await IERC20.at(dai);
    await daiToken.approve(dai777.address, eth(100));
    await dai777.wrap(eth(100));
  });

  it('should deposit and withdraw Dai from Aave', async function () {
    const aaveAdapter = await AaveAdapter.new(aaveAddressProvider.address, weth, defaultSender);
    await aaveAdapter.setWrappedAToken(dai777.address, aDai777.address);

    await dai777.transfer(aaveAdapter.address, eth(1));

    expect(await str(aDai777.balanceOf(defaultSender))).to.equal(eth(1));

    await aDai777.transfer(user1, eth(1));

    await aDai777.transfer(aaveAdapter.address, eth(0.4), { from: user1 });

    expect(await str(aDai777.balanceOf(user1))).to.equal(eth(0.6));
    expect(await str(dai777.balanceOf(user1))).to.equal(eth(0.4));
  });

  it('should deposit and withdraw ETH from Aave using aaveAdapter', async function () {
    const aaveAdapter = await AaveAdapter.new(aaveAddressProvider.address, weth, defaultSender);
    await aaveAdapter.setWrappedAToken(weth, aWeth777.address);

    await aaveAdapter.sendTransaction({ value: eth(0.1) });

    expect(await str(aWeth777.balanceOf(defaultSender))).to.equal(eth(0.1));

    await aWeth777.transfer(user1, eth(0.1));

    expect(await str(aWeth777.balanceOf(user1))).to.equal(eth(0.1));

    const startingBalance = await web3.eth.getBalance(user1);
    const { receipt } = await aWeth777.transfer(aaveAdapter.address, eth(0.1), { from: user1, gasPrice: ONE_GWEI });

    const ethSpentOnGas = ONE_GWEI * receipt.gasUsed;
    expect(await web3.eth.getBalance(user1))
      .to.equal((toBN(startingBalance).add(toBN(eth(0.1))).sub(toBN(ethSpentOnGas))).toString());
  });
});
