const { getContract, web3, group, getAccounts, str, getDefiAddresses, eth } = require('./test-lib');
const { singletons } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const UniswapAdapter = getContract('UniswapAdapter');
const UniswapAdapterFactory = getContract('UniswapAdapterFactory');
const UniswapPoolAdapterFactory = getContract('UniswapPoolAdapterFactory');
const UniswapPoolAdapter = getContract('UniswapPoolAdapter');
const UniswapETHAdapter = getContract('UniswapETHAdapter');
const WrapperFactory = getContract('WrapperFactory');
const Wrapped777 = getContract('Wrapped777');
const TestERC20 = getContract('TestERC20');
const TestUniswapRouter = getContract('TestUniswapRouter');
const TestUniswapPair = getContract('TestUniswapPair');
const IERC20 = getContract('IERC20');
const IWETH = getContract('IWETH');

const ONE_GWEI = 1000000000;
const { toBN } = web3.utils;

group('Uniswap Pools', (accounts) => {
  const [defaultSender, user] = getAccounts(accounts);

  let weth, dai;

  before(() => singletons.ERC1820Registry(defaultSender));

  it('should join a Uniswap pool with ETH', async function() {
    this.timeout(3000);

    const uniswapRouter = await TestUniswapRouter.new();

    const dai = await TestERC20.new();
    const weth = await IWETH.at(await uniswapRouter.WETH());

    const pair = await TestUniswapPair.new(weth.address, dai.address);
    await pair.setFactory(await uniswapRouter.factory());
    await dai.transfer(pair.address, eth(50));
    await weth.deposit({ value: eth(2) });
    await weth.transfer(pair.address, eth(2));
    await pair.mint(defaultSender);

    const wrapperFactory = await WrapperFactory.new();
    const poolFactory = await UniswapPoolAdapterFactory.new(uniswapRouter.address);

    await wrapperFactory.createWrapper(pair.address);
    const poolWrapperAddress = await wrapperFactory.calculateWrapperAddress(pair.address);
    const poolWrapper = await Wrapped777.at(poolWrapperAddress);

    await poolFactory.createAdapter(poolWrapperAddress);
    const poolAdapter = await UniswapPoolAdapter.at(await poolFactory.calculateAdapterAddress(poolWrapperAddress));

    await poolAdapter.sendTransaction({ value: eth(1), from: user });

    expect(await str(poolWrapper.balanceOf(user))).to.equal('2244072941151344688');

    // Exit
    const adapter = await UniswapETHAdapter.new(uniswapRouter.address);

    const startingBalance = await web3.eth.getBalance(user);

    const { receipt } = await poolWrapper.transfer(adapter.address, '2244072941151344688', {
      from: user,
      gasPrice: ONE_GWEI,
    });

    const ethSpentOnGas = ONE_GWEI * receipt.gasUsed;
    expect(await web3.eth.getBalance(user))
      .to.equal((toBN(startingBalance).add(toBN('549834916519288928')).sub(toBN(ethSpentOnGas))).toString());
  });

  it('should join a Uniswap pool with Dai777', async function() {
    this.timeout(3000);

    const uniswapRouter = await TestUniswapRouter.new();
    const wrapperFactory = await WrapperFactory.new();
    const poolFactory = await UniswapPoolAdapterFactory.new(uniswapRouter.address);

    const dai = await TestERC20.new();
    const weth = await IWETH.at(await uniswapRouter.WETH());

    const daiWrapperAddress = await wrapperFactory.calculateWrapperAddress(dai.address);
    await wrapperFactory.createWrapper(dai.address);
    const daiWrapper = await Wrapped777.at(daiWrapperAddress);
    await dai.approve(daiWrapperAddress, eth(10));
    await daiWrapper.wrapTo(eth(10), user);

    const pair = await TestUniswapPair.new(weth.address, dai.address);
    await pair.setFactory(await uniswapRouter.factory());
    await dai.transfer(pair.address, eth(50));
    await weth.deposit({ value: eth(1) });
    await weth.transfer(pair.address, eth(1));
    await pair.mint(defaultSender);

    await wrapperFactory.createWrapper(pair.address);
    const poolWrapperAddress = await wrapperFactory.calculateWrapperAddress(pair.address);
    const poolWrapper = await Wrapped777.at(poolWrapperAddress);

    await poolFactory.createAdapter(poolWrapperAddress);
    const poolAdapter = await UniswapPoolAdapter.at(await poolFactory.calculateAdapterAddress(poolWrapperAddress));

    await daiWrapper.transfer(poolAdapter.address, eth(10), { from: user });

    expect(await str(poolWrapper.balanceOf(user))).to.equal('673885077677817013');

    // Exit
    const uniswapFactory = await UniswapAdapterFactory.new(uniswapRouter.address);

    await uniswapFactory.createAdapter(daiWrapperAddress);
    const adapterAddress = await uniswapFactory.calculateAdapterAddress(daiWrapperAddress);

    await poolWrapper.transfer(adapterAddress, '673885077677817013', { from: user });

    expect(await str(daiWrapper.balanceOf(user))).to.equal('5220574642262710734');
  });
});
