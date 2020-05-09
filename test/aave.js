const { getContract, web3, group, getAccounts, str, getDefiAddresses } = require('./test-lib');
const { singletons } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

// const TestERC20 = getContract('TestERC20');
// const TestUniswapRouter = getContract('TestUniswapRouter');
const AToken777 = getContract('AToken777');
const IERC20 = getContract('IERC20');
const WrapperFactory = getContract('WrapperFactory');
const Wrapped777 = getContract('Wrapped777');
const Aave777 = getContract('Aave777');

const { toWei, toBN } = web3.utils;

const ONE_GWEI = 1000000000;

const ETH_FAKE_ADDRESS = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';

group('Aave', (accounts) => {
  const [defaultSender, user1, user2] = getAccounts(accounts);
  let dai, aave, dai777;

  before(async function () {
    this.timeout(3000);

    await singletons.ERC1820Registry(defaultSender);
    ({ dai, aave } = await getDefiAddresses());

    const factory = await WrapperFactory.new();
    await factory.create(dai);
    dai777 = await Wrapped777.at(await factory.getWrapper(dai));

    const daiToken = await IERC20.at(dai);
    await daiToken.approve(dai777.address, toWei('100', 'ether'));
    await dai777.wrap(toWei('100', 'ether'));
  });

  it('should deposit and withdraw Dai from Aave using Aave777', async function () {
    this.timeout(10000);
    const aave777 = await Aave777.new(aave);

    await dai777.transfer(aave777.address, toWei('1', 'ether'));

    const aDai777Address = await aave777.calculateWrapperAddress(dai777.address);
    const aDai777 = await AToken777.at(aDai777Address);

    expect(await str(aDai777.balanceOf(defaultSender))).to.equal(toWei('1', 'ether'));

    await aDai777.transfer(user1, toWei('1', 'ether'));

    await aDai777.transfer(aave777.address, toWei('0.4', 'ether'), { from: user1 });

    expect(await str(aDai777.balanceOf(user1))).to.equal(toWei('0.6', 'ether'));
    expect(await str(dai777.balanceOf(user1))).to.equal(toWei('0.4', 'ether'));
  });

  it('should deposit and withdraw Dai from Aave using the AToken777', async function () {
    this.timeout(3000);
    const aave777 = await Aave777.new(aave);

    await aave777.getWrapperAddress(dai777.address);
    const aDai777Address = await aave777.calculateWrapperAddress(dai777.address);
    await dai777.transfer(aDai777Address, toWei('1', 'ether'));
    const aDai777 = await AToken777.at(aDai777Address);

    expect(await str(aDai777.balanceOf(defaultSender))).to.equal(toWei('1', 'ether'));

    await aDai777.transfer(user2, toWei('1', 'ether'));

    await aDai777.transfer(aDai777.address, toWei('0.4', 'ether'), { from: user2 });

    expect(await str(aDai777.balanceOf(user2))).to.equal(toWei('0.6', 'ether'));
    expect(await str(dai777.balanceOf(user2))).to.equal(toWei('0.4', 'ether'));
  });

  it('should deposit and withdraw ETH from Aave using Aave777', async function () {
    this.timeout(10000);
    const aave777 = await Aave777.new(aave);

    await aave777.sendTransaction({ value: toWei('0.1', 'ether') });

    const aETH777Address = await aave777.calculateWrapperAddress(ETH_FAKE_ADDRESS);
    const aETH777 = await AToken777.at(aETH777Address);

    expect(await str(aETH777.balanceOf(defaultSender))).to.equal(toWei('0.1', 'ether'));

    await aETH777.transfer(user1, toWei('0.1', 'ether'));

    expect(await str(aETH777.balanceOf(user1))).to.equal(toWei('0.1', 'ether'));

    const startingBalance = await web3.eth.getBalance(user1);
    const { receipt } = await aETH777.transfer(aave777.address, toWei('0.1', 'ether'), { from: user1, gasPrice: ONE_GWEI });

    const ethSpentOnGas = ONE_GWEI * receipt.gasUsed;
    expect(await web3.eth.getBalance(user1))
      .to.equal((toBN(startingBalance).add(toBN(toWei('0.1', 'ether'))).sub(toBN(ethSpentOnGas))).toString());
  });

  it('should deposit and withdraw ETH from Aave using the AToken777', async function () {
    this.timeout(3000);
    const aave777 = await Aave777.new(aave);

    await aave777.getWrapperAddress(ETH_FAKE_ADDRESS);
    const aETH777Address = await aave777.calculateWrapperAddress(ETH_FAKE_ADDRESS);
    const aETH777 = await AToken777.at(aETH777Address);
    await aETH777.sendTransaction({ value: toWei('0.1', 'ether') });

    expect(await str(aETH777.balanceOf(defaultSender))).to.equal(toWei('0.1', 'ether'));

    await aETH777.transfer(user2, toWei('0.1', 'ether'));

    const startingBalance = await web3.eth.getBalance(user2);
    const { receipt } = await aETH777.transfer(aETH777.address, toWei('0.1', 'ether'), { from: user2, gasPrice: ONE_GWEI });

    const ethSpentOnGas = ONE_GWEI * receipt.gasUsed;
    expect(await web3.eth.getBalance(user2))
      .to.equal((toBN(startingBalance).add(toBN(toWei('0.1', 'ether'))).sub(toBN(ethSpentOnGas))).toString());
  });
});
