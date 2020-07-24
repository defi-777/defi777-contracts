const { getContract, web3, group, getAccounts, str } = require('./test-lib');
const { singletons } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const TestERC20 = getContract('TestERC20');
const TestUniswapRouter = getContract('TestUniswapRouter');
const UniswapWrapper = getContract('UniswapWrapper');
const TestSynthetix = getContract('TestSynthetix');
const SynthExchangeFactory = getContract('SynthExchangeFactory');
const SynthExchange = getContract('SynthExchange');
const TestSynth = getContract('TestSynth');
const WrapperFactory = getContract('WrapperFactory');
const Wrapped777 = getContract('Wrapped777');

const { toWei, toBN } = web3.utils;

const eth = num => toWei(num, 'ether');

const ONE_GWEI = 1000000000;

group('Synthetix', (accounts) => {
  const [defaultSender, user] = getAccounts(accounts);

  before(() => singletons.ERC1820Registry(defaultSender));

  it('Should swap sUSD for sBTC', async () => {
    const wrapperFactory = await WrapperFactory.new();
    const synthetix = await TestSynthetix.new();

    const susdAddress = await synthetix.synths(web3.utils.fromUtf8('sUSD'));
    await wrapperFactory.create(susdAddress);
    const susdWrapperAddress = await wrapperFactory.getWrapper(susdAddress);
    const susdWrapper = await Wrapped777.at(susdWrapperAddress);

    const sbtcAddress = await synthetix.synths(web3.utils.fromUtf8('sBTC'));
    await wrapperFactory.create(sbtcAddress);
    const sbtcWrapperAddress = await wrapperFactory.getWrapper(sbtcAddress);
    const sbtcWrapper = await Wrapped777.at(sbtcWrapperAddress);

    const synthxFactory = await SynthExchangeFactory.new(synthetix.address, '0x0000000000000000000000000000000000000000');
    await synthxFactory.createExchange(sbtcWrapperAddress);
    const sbtcExchange = await synthxFactory.calculateExchangeAddress(sbtcWrapperAddress);

    const susd = await TestSynth.at(susdAddress);
    await susd.issue(defaultSender, eth('2'));
    await susd.approve(susdWrapperAddress, eth('2'));
    await susdWrapper.wrap(eth('2'));

    await susdWrapper.transfer(sbtcExchange, eth('2'));

    expect(await str(sbtcWrapper.balanceOf(defaultSender))).to.equal(eth('1'));
  });


  it('Should swap ETH for sBTC', async () => {
    const wrapperFactory = await WrapperFactory.new();
    const synthetix = await TestSynthetix.new();
    const uniswapRouter = await TestUniswapRouter.new();

    const susdAddress = await synthetix.synths(web3.utils.fromUtf8('sUSD'));
    const susd = await TestSynth.at(susdAddress);
    await susd.issue(uniswapRouter.address, eth('1'));

    const sbtcAddress = await synthetix.synths(web3.utils.fromUtf8('sBTC'));
    await wrapperFactory.create(sbtcAddress);
    const sbtcWrapperAddress = await wrapperFactory.getWrapper(sbtcAddress);
    const sbtcWrapper = await Wrapped777.at(sbtcWrapperAddress);

    const synthxFactory = await SynthExchangeFactory.new(synthetix.address, uniswapRouter.address);
    await synthxFactory.createExchange(sbtcWrapperAddress);
    const sbtcExchangeAddress = await synthxFactory.calculateExchangeAddress(sbtcWrapperAddress);
    const sbtcExchange = await SynthExchange.at(sbtcExchangeAddress);

    await sbtcExchange.sendTransaction({ value: eth('1'), from: defaultSender });

    expect(await str(sbtcWrapper.balanceOf(defaultSender))).to.equal(eth('0.5'));
  });

  it('Should swap a 777 token for sBTC', async () => {
    const wrapperFactory = await WrapperFactory.new();
    const uniswapRouter = await TestUniswapRouter.new();
    const synthetix = await TestSynthetix.new();
    const token1 = await TestERC20.new();

    await wrapperFactory.create(token1.address);
    const wrapper1Address = await wrapperFactory.getWrapper(token1.address);
    const wrapper1 = await Wrapped777.at(wrapper1Address);
    await token1.approve(wrapper1Address, eth('2'));
    await wrapper1.wrap(eth('2'));

    const susdAddress = await synthetix.synths(web3.utils.fromUtf8('sUSD'));
    const susd = await TestSynth.at(susdAddress);
    await susd.issue(uniswapRouter.address, eth('1'));

    const sbtcAddress = await synthetix.synths(web3.utils.fromUtf8('sBTC'));
    await wrapperFactory.create(sbtcAddress);
    const sbtcWrapperAddress = await wrapperFactory.getWrapper(sbtcAddress);
    const sbtcWrapper = await Wrapped777.at(sbtcWrapperAddress);

    const synthxFactory = await SynthExchangeFactory.new(synthetix.address, uniswapRouter.address);
    await synthxFactory.createExchange(sbtcWrapperAddress);
    const sbtcExchangeAddress = await synthxFactory.calculateExchangeAddress(sbtcWrapperAddress);
    const sbtcExchange = await SynthExchange.at(sbtcExchangeAddress);

    await wrapper1.transfer(sbtcExchangeAddress, eth('1'), { from: defaultSender });
    expect(await str(sbtcWrapper.balanceOf(defaultSender))).to.equal(eth('0.5'));
  });
});
