const { getContract, web3, group, getAccounts, str } = require('./test-lib');
const { singletons } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const TestERC20 = getContract('TestERC20');
const TestUniswapRouter = getContract('TestUniswapRouter');
const UniswapWrapper = getContract('UniswapWrapper');
const UniswapWrapperFactory = getContract('UniswapWrapperFactory');
const WrapperFactory = getContract('WrapperFactory');
const Wrapped777 = getContract('Wrapped777');

const { toWei } = web3.utils;

const ONE_GWEI = 1000000000;

group('Uniswap', (accounts) => {
  const [defaultSender, user] = getAccounts(accounts);

  before(() => singletons.ERC1820Registry(defaultSender));

  it('Should swap ETH for a token', async () => {
    const token = await TestERC20.new();
    const factory = await WrapperFactory.new();

    await factory.create(token.address);
    const wrapperAddress = await factory.getWrapper(token.address);
    const wrapper = await Wrapped777.at(wrapperAddress);

    const uniswapRouter = await TestUniswapRouter.new();
    await token.transfer(uniswapRouter.address, toWei('100', 'ether'));

    const uniswapFactory = await UniswapWrapperFactory.new(uniswapRouter.address);
    await uniswapFactory.createExchange(wrapper.address);
    const exchangeAddress = await uniswapFactory.getWrapper(wrapper.address);
    const exchange = await UniswapWrapper.at(exchangeAddress);

    await exchange.sendTransaction({ value: toWei('1', 'ether'), from: user });
    expect(await str(wrapper.balanceOf(user))).to.equal(toWei('1', 'ether'));
  });

  it('Should swap a 777 token for ETH', async () => {
    const token = await TestERC20.new();
    const factory = await WrapperFactory.new();

    await factory.create(token.address);
    const wrapperAddress = await factory.getWrapper(token.address);
    const wrapper = await Wrapped777.at(wrapperAddress);

    await token.approve(wrapperAddress, toWei('10', 'ether'));
    await wrapper.wrap(toWei('10', 'ether'));
    await wrapper.transfer(user, toWei('2', 'ether'));

    const uniswapRouter = await TestUniswapRouter.new();
    await uniswapRouter.sendTransaction({ value: toWei('2', 'ether') });

    const uniswapFactory = await UniswapWrapperFactory.new(uniswapRouter.address);
    await uniswapFactory.createExchange(wrapper.address);
    const exchangeAddress = await uniswapFactory.getWrapper(wrapper.address);
    const exchange = await UniswapWrapper.at(exchangeAddress);

    const startingBalance = await web3.eth.getBalance(user)
    const { receipt } = await wrapper.transfer(exchangeAddress, toWei('1', 'ether'), { from: user, gasPrice: ONE_GWEI });

    const ethSpentOnGas = ONE_GWEI * receipt.gasUsed;
    expect(await web3.eth.getBalance(user))
      .to.equal((parseInt(startingBalance) + parseInt(toWei('1', 'ether')) - ethSpentOnGas).toString());
  });

  it('Should swap a 777 token for another token', async () => {
    const factory = await WrapperFactory.new();

    const token1 = await TestERC20.new();
    const token2 = await TestERC20.new();

    await factory.create(token1.address);
    await factory.create(token2.address);
    const wrapper1Address = await factory.getWrapper(token1.address);
    const wrapper2Address = await factory.getWrapper(token2.address);
    const wrapper1 = await Wrapped777.at(wrapper1Address);
    const wrapper2 = await Wrapped777.at(wrapper2Address);

    const uniswapRouter = await TestUniswapRouter.new();
    await token1.transfer(uniswapRouter.address, toWei('100', 'ether'));

    await token2.approve(wrapper2Address, toWei('10', 'ether'));
    await wrapper2.wrap(toWei('10', 'ether'));
    await wrapper2.transfer(user, toWei('2', 'ether'));

    const uniswapFactory = await UniswapWrapperFactory.new(uniswapRouter.address);
    await uniswapFactory.createExchange(wrapper1.address);
    const exchangeAddress = await uniswapFactory.getWrapper(wrapper1.address);
    const exchange = await UniswapWrapper.at(exchangeAddress);

    await wrapper2.transfer(exchangeAddress, toWei('1', 'ether'), { from: user });
    expect(await str(wrapper1.balanceOf(user))).to.equal(toWei('1', 'ether'));
  });
});
