const { getContract, web3, group, getAccounts, str, getWrapperFactory, eth } = require('./test-lib');
const { singletons } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const YVaultAdapter = getContract('YVaultAdapter');
const YVaultAdapterFactory = getContract('YVaultAdapterFactory');
const WrapperFactory = getContract('WrapperFactory');
const Wrapped777 = getContract('Wrapped777');
const TestYVault = getContract('TestYVault');
const IERC20 = getContract('IERC20');
const TestERC20 = getContract('TestERC20');
const WETH = getContract('WETH');

const ONE_GWEI = 1000000000;
const ZERO = '0x0000000000000000000000000000000000000000';
const { toWei, toBN } = web3.utils;

group('yEarn', (accounts) => {
  const [defaultSender, user] = getAccounts(accounts);

  before(() => singletons.ERC1820Registry(defaultSender));

  it('should join and exit a yEarn vault', async () => {
    const wrapperFactory = await WrapperFactory.new();
    const token = await TestERC20.new();

    const vault = await TestYVault.new(token.address);

    const factory = await getWrapperFactory();
    const [tokenWrapper, vaultWrapper] = await factory.getWrappers([token.address, vault.address]);

    await token.approve(tokenWrapper.address, eth(1));
    await tokenWrapper.wrapTo(eth(1), user);

    const weth = await WETH.new();
    const adapterFactory = await YVaultAdapterFactory.new(weth.address);
    await adapterFactory.createAdapter(vaultWrapper.address, tokenWrapper.address);
    const adapterAddress = await adapterFactory.calculateAdapterAddress(vaultWrapper.address, tokenWrapper.address);

    await tokenWrapper.transfer(adapterAddress, eth(1), { from: user });

    expect(await str(vaultWrapper.balanceOf(user))).to.equal(eth(1));

    // Exit
    await vaultWrapper.transfer(adapterAddress, eth(1), { from: user });
    expect(await str(tokenWrapper.balanceOf(user))).to.equal(eth(1));
  });

  it('should join and exit an ETH yEarn vault', async () => {
    const wrapperFactory = await WrapperFactory.new();
    const token = await TestERC20.new();
    const weth = await WETH.new();

    const vault = await TestYVault.new(weth.address);

    const factory = await getWrapperFactory();
    const vaultWrapper = await factory.getWrapper(vault.address);

    const adapterFactory = await YVaultAdapterFactory.new(weth.address);
    await adapterFactory.createAdapter(vaultWrapper.address, ZERO);
    const adapterAddress = await adapterFactory.calculateAdapterAddress(vaultWrapper.address, ZERO);

    await web3.eth.sendTransaction({ to: adapterAddress, from: user, value: eth('0.1'), gas: '1000000' });

    expect(await str(vaultWrapper.balanceOf(user))).to.equal(eth('0.1'));

    // Exit
    const startingBalance = await web3.eth.getBalance(user);
    const { receipt } = await vaultWrapper.transfer(adapterAddress, eth('0.1'), { from: user, gasPrice: ONE_GWEI });

    const ethSpentOnGas = ONE_GWEI * receipt.gasUsed;
    expect(await web3.eth.getBalance(user))
      .to.equal((toBN(startingBalance).add(toBN(eth('0.1'))).sub(toBN(ethSpentOnGas))).toString());
  });
});
