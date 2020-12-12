const { getContract, web3, group, getAccounts, str, eth, getDefiAddresses, getWrapperFactory } = require('./test-lib');
const { singletons } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const IERC20 = getContract('IERC20');
const CompoundAdapter = getContract('CompoundAdapter');
const MockCEther = getContract('MockCEther');
const MockCToken = getContract('MockCToken');

const { toBN } = web3.utils;

const ONE_GWEI = 1000000000;

group('Compound', (accounts) => {
  const [defaultSender, user1, user2] = getAccounts(accounts);
  let dai, dai777, cDai, cDai777, cETH, cETH777;

  before(async function () {
    await singletons.ERC1820Registry(defaultSender);
    ({ dai } = await getDefiAddresses());

    cDai = await MockCToken.new(dai);
    cETH = await MockCEther.new();

    const { getWrappers } = await getWrapperFactory();

    ([dai777, cDai777, cETH777] = await getWrappers([dai, cDai, cETH]));

    const daiToken = await IERC20.at(dai);
    await daiToken.approve(dai777.address, eth(100));
    await dai777.wrap(eth(100));
  });

  it('should deposit and withdraw Dai from Compound', async function () {
    const compoundAdapter = await CompoundAdapter.new();
    await compoundAdapter.setWrappedCToken(dai777.address, cDai777.address);

    await dai777.transfer(compoundAdapter.address, eth(1));

    expect(await str(cDai777.balanceOf(defaultSender))).to.equal(eth(1));

    await cDai777.transfer(user1, eth(1));

    await cDai777.transfer(compoundAdapter.address, eth(0.4), { from: user1 });

    expect(await str(cDai777.balanceOf(user1))).to.equal(eth(0.6));
    expect(await str(dai777.balanceOf(user1))).to.equal(eth(0.4));
  });

  it('should deposit and withdraw ETH from Compound', async function () {
    const compoundAdapter = await CompoundAdapter.new();
    await compoundAdapter.setWrappedCToken('0x0000000000000000000000000000000000000001', cETH777.address);

    await compoundAdapter.sendTransaction({ value: eth(0.1) });

    expect(await str(cETH777.balanceOf(defaultSender))).to.equal(eth(0.1));

    await cETH777.transfer(user1, eth(0.1));

    expect(await str(cETH777.balanceOf(user1))).to.equal(eth(0.1));

    const startingBalance = await web3.eth.getBalance(user1);
    const { receipt } = await cETH777.transfer(compoundAdapter.address, eth(0.1), { from: user1, gasPrice: ONE_GWEI });

    const ethSpentOnGas = ONE_GWEI * receipt.gasUsed;
    expect(await web3.eth.getBalance(user1))
      .to.equal((toBN(startingBalance).add(toBN(eth(0.1))).sub(toBN(ethSpentOnGas))).toString());
  });
});
