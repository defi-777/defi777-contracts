const { getContract, web3, group, getAccounts, str, eth, getWrappedToken } = require('./test-lib');
const { singletons } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const IUniswapV2Factory = getContract('IUniswapV2Factory');
const IUniswapV2Pair = getContract('IUniswapV2Pair');
const TestERC20 = getContract('TestERC20');
const TestUniswapRouter = getContract('TestUniswapRouter');
const UniswapAdapter = getContract('UniswapAdapter');
const UniswapAdapterFactory = getContract('UniswapAdapterFactory');
const UniswapETHAdapter = getContract('UniswapETHAdapter');
const WrapperFactory = getContract('WrapperFactory');
const Wrapped777 = getContract('Wrapped777');
const IWETH = getContract('IWETH');

const { toWei, toBN } = web3.utils;

const ONE_GWEI = 1000000000;

async function setupUniswap(token1, token2) {
  const uniswapRouter = await TestUniswapRouter.new();

  let token2Amt = '50';

  if (!token2) {
    token2 = await IWETH.at(await uniswapRouter.WETH());
    await token2.deposit({ value: eth(1) });
    token2Amt = '1';
  }

  const uniswapFactory = await IUniswapV2Factory.at(await uniswapRouter.factory());
  await uniswapFactory.createPair(token1.address, token2.address);
  const pair = await IUniswapV2Pair.at(await uniswapFactory.getPair(token1.address, token2.address));

  await Promise.all([
    token1.transfer(pair.address, eth(50)),
    token2.transfer(pair.address, eth(token2Amt)),
  ]);
  await pair.mint('0x0000000000000000000000000000000000000001');

  return { uniswapRouter, uniswapFactory, pair };
}

group('Uniswap', (accounts) => {
  const [defaultSender, user] = getAccounts(accounts);

  before(() => singletons.ERC1820Registry(defaultSender));

  it('Should swap ETH for a token', async () => {
    const token = await TestERC20.new();
    const factory = await WrapperFactory.new();

    await factory.createWrapper(token.address);
    const wrapperAddress = await factory.calculateWrapperAddress(token.address);
    const wrapper = await Wrapped777.at(wrapperAddress);

    const { uniswapRouter } = await setupUniswap(token);

    const uniswapFactory = await UniswapAdapterFactory.new(uniswapRouter.address);
    await uniswapFactory.createAdapter(wrapper.address);
    const exchangeAddress = await uniswapFactory.calculateAdapterAddress(wrapper.address);
    const exchange = await UniswapAdapter.at(exchangeAddress);

    await exchange.sendTransaction({ value: toWei('0.5', 'ether'), from: user });
    expect(await str(wrapper.balanceOf(user))).to.equal('16633299966633299966');
  });

  it('Should swap a 777 token for ETH', async () => {
    const token = await TestERC20.new();
    const factory = await WrapperFactory.new();

    await factory.createWrapper(token.address);
    const wrapperAddress = await factory.calculateWrapperAddress(token.address);
    const wrapper = await Wrapped777.at(wrapperAddress);

    await token.approve(wrapperAddress, toWei('10', 'ether'));
    await wrapper.wrap(toWei('10', 'ether'));
    await wrapper.transfer(user, toWei('2', 'ether'));

    const { uniswapRouter } = await setupUniswap(token);

    const uniswapFactory = await UniswapAdapterFactory.new(uniswapRouter.address);
    await uniswapFactory.createAdapter(wrapper.address);
    const exchangeAddress = await uniswapFactory.calculateAdapterAddress(wrapper.address);
    const exchange = await UniswapAdapter.at(exchangeAddress);

    const startingBalance = await web3.eth.getBalance(user)
    const { receipt, logs } = await wrapper.transfer(exchangeAddress, eth(1), { from: user, gasPrice: ONE_GWEI });

    const ethSpentOnGas = ONE_GWEI * receipt.gasUsed;
    expect(await web3.eth.getBalance(user))
      .to.equal((toBN(startingBalance).add(toBN(19550169617820656)).sub(toBN(ethSpentOnGas))).toString());
  });

  it('Should swap a 777 token for ETH using the ETH Adapter', async () => {
    const [wrapper, token] = await getWrappedToken();
    await wrapper.transfer(user, toWei('2', 'ether'));

    const { uniswapRouter } = await setupUniswap(token);

    const adapter = await UniswapETHAdapter.new(uniswapRouter.address);

    const startingBalance = await web3.eth.getBalance(user)
    const { receipt, logs } = await wrapper.transfer(adapter.address, eth(1), { from: user, gasPrice: ONE_GWEI });

    const ethSpentOnGas = ONE_GWEI * receipt.gasUsed;
    expect(await web3.eth.getBalance(user))
      .to.equal((toBN(startingBalance).add(toBN(19550169617820656)).sub(toBN(ethSpentOnGas))).toString());
  });

  it('Should swap a 777 token for another token', async () => {
    const factory = await WrapperFactory.new();

    const token1 = await TestERC20.new();
    const token2 = await TestERC20.new();

    await factory.createWrapper(token1.address);
    await factory.createWrapper(token2.address);
    const wrapper1Address = await factory.calculateWrapperAddress(token1.address);
    const wrapper2Address = await factory.calculateWrapperAddress(token2.address);
    const wrapper1 = await Wrapped777.at(wrapper1Address);
    const wrapper2 = await Wrapped777.at(wrapper2Address);

    const { uniswapRouter } = await setupUniswap(token1, token2);

    await token2.approve(wrapper2Address, toWei('10', 'ether'));
    await wrapper2.wrap(toWei('10', 'ether'));
    await wrapper2.transfer(user, toWei('2', 'ether'));

    const uniswapFactory = await UniswapAdapterFactory.new(uniswapRouter.address);
    await uniswapFactory.createAdapter(wrapper1.address);
    const exchangeAddress = await uniswapFactory.calculateAdapterAddress(wrapper1.address);
    const exchange = await UniswapAdapter.at(exchangeAddress);

    await wrapper2.transfer(exchangeAddress, eth(1), { from: user });
    expect(await str(wrapper1.balanceOf(user))).to.equal('977508480891032805');
  });
});
