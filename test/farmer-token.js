const { getContract, web3, group, getAccounts, str, getDefiAddresses, eth } = require('./test-lib');
const { singletons } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const FarmerToken = getContract('FarmerToken');
const FarmerTokenFactory = getContract('FarmerTokenFactory');
const YieldAdapterFactory = getContract('YieldAdapterFactory');
const TestERC20 = getContract('TestERC20');
const WrapperFactory = getContract('WrapperFactory');

group('Farmer Token', (accounts) => {
  const [admin, user1, user2, user3, pool] = getAccounts(accounts);

  before(async () => {
    await singletons.ERC1820Registry(user1);
  });

  it('should allocate tokens correctly', async function() {
    this.timeout(10000);

    const wrapperFactory = await WrapperFactory.new();
    const adapterFactory = await YieldAdapterFactory.new('0x0000000000000000000000000000000000000000');
    const factory = await FarmerTokenFactory.new(adapterFactory.address);
    const token = await TestERC20.new();
    const reward1 = await TestERC20.new();

    await wrapperFactory.createWrapper(reward1.address);
    const rewardWrapperAddress = await wrapperFactory.calculateWrapperAddress(reward1.address);

    await factory.createWrapper(token.address, [rewardWrapperAddress]);
    const wrapperAddress = await factory.calculateWrapperAddress(token.address, [rewardWrapperAddress]);
    const farmerToken = await FarmerToken.at(wrapperAddress);
    expect(await farmerToken.rewardTokens()).to.deep.equal([reward1.address]);
    expect(await farmerToken.underlyingTokens()).to.deep.equal([token.address, reward1.address]);

    await token.transfer(user1, eth(2), { from: admin });
    await token.approve(wrapperAddress, eth(10), { from: user1 });
    await farmerToken.wrap(eth(2), { from: user1 });

    await reward1.transfer(farmerToken.address, eth(2));
    await farmerToken.harvest(reward1.address);
    expect(await str(farmerToken.rewardBalance(reward1.address, user1))).to.equal(eth('2'));

    await token.transfer(user2, eth(6), { from: admin });
    await token.approve(wrapperAddress, eth(6), { from: user2 });
    await farmerToken.wrap(eth(6), { from: user2 });

    await reward1.transfer(farmerToken.address, eth(8));
    await farmerToken.harvest(reward1.address);
    expect(await str(farmerToken.rewardBalance(reward1.address, user1))).to.equal(eth('4'));
    expect(await str(farmerToken.rewardBalance(reward1.address, user2))).to.equal(eth('6'));
    expect(await str(farmerToken.balanceOfUnderlying(user1, reward1.address))).to.equal(eth(4));

    await farmerToken.withdraw(reward1.address, eth(2), { from: user2 });
    expect(await str(reward1.balanceOf(user2))).to.equal(eth(2));
    expect(await str(farmerToken.rewardBalance(reward1.address, user1))).to.equal(eth('4'));
    expect(await str(farmerToken.rewardBalance(reward1.address, user2))).to.equal(eth('4'));

    await farmerToken.transfer(user3, eth('3'), { from: user2 });
    expect(await str(farmerToken.rewardBalance(reward1.address, user1))).to.equal(eth('4'));
    expect(await str(farmerToken.rewardBalance(reward1.address, user2))).to.equal(eth('2'));
    expect(await str(farmerToken.rewardBalance(reward1.address, user3))).to.equal(eth('2'));

    await reward1.transfer(farmerToken.address, eth(8));
    await farmerToken.harvest(reward1.address);
    await farmerToken.withdraw(reward1.address, eth(4), { from: user1 });
    expect(await str(farmerToken.rewardBalance(reward1.address, user1))).to.equal(eth('2'));
    expect(await str(farmerToken.rewardBalance(reward1.address, user2))).to.equal(eth('5'));
    expect(await str(farmerToken.rewardBalance(reward1.address, user3))).to.equal(eth('5'));

    await farmerToken.transfer(pool, eth('2'), { from: user1 });
    await farmerToken.transfer(pool, eth('3'), { from: user2 });
    await farmerToken.transfer(pool, eth('3'), { from: user3 });
    expect(await str(farmerToken.rewardBalance(reward1.address, user1))).to.equal('0');
    expect(await str(farmerToken.rewardBalance(reward1.address, user2))).to.equal('0');
    expect(await str(farmerToken.rewardBalance(reward1.address, user3))).to.equal('0');
    expect(await str(farmerToken.rewardBalance(reward1.address, pool))).to.equal(eth('12'));

    await reward1.transfer(farmerToken.address, eth(4));
    await farmerToken.harvest(reward1.address);

    expect(await str(farmerToken.rewardBalance(reward1.address, pool))).to.equal(eth('16'));

    await farmerToken.transfer(user1, eth('2'), { from: pool });
    await farmerToken.transfer(user2, eth('3'), { from: pool });
    await farmerToken.transfer(user3, eth('3'), { from: pool });
    expect(await str(farmerToken.rewardBalance(reward1.address, user1))).to.equal(eth('4'));
    expect(await str(farmerToken.rewardBalance(reward1.address, user2))).to.equal(eth('6'));
    expect(await str(farmerToken.rewardBalance(reward1.address, user3))).to.equal(eth('6'));
  });

  it('should let users withdraw using yield tokens', async () => {
    const wrapperFactory = await WrapperFactory.new();
    const adapterFactory = await YieldAdapterFactory.new(wrapperFactory.address);
    const farmerFactory = await FarmerTokenFactory.new(adapterFactory.address);
    const token = await TestERC20.new();
    const reward1 = await TestERC20.new();

    await wrapperFactory.createWrapper(reward1.address);
    const rewardWrapperAddress = await wrapperFactory.calculateWrapperAddress(reward1.address);

    await farmerFactory.createWrapper(token.address, [rewardWrapperAddress]);
    const wrapperAddress = await farmerFactory.calculateWrapperAddress(token.address, [rewardWrapperAddress]);
    const farmerToken = await FarmerToken.at(wrapperAddress);

    const reward1Wrapper = await TestERC20.at(rewardWrapperAddress);
    const reward1Adapter = await TestERC20.at(await adapterFactory.calculateWrapperAddress(wrapperAddress, rewardWrapperAddress));

    await token.transfer(user1, eth(2), { from: admin });
    await token.approve(wrapperAddress, eth(10), { from: user1 });
    await farmerToken.wrap(eth(2), { from: user1 });

    await reward1.transfer(farmerToken.address, eth(2));
    await farmerToken.harvest(reward1.address);
    expect(await str(farmerToken.rewardBalance(reward1.address, user1))).to.equal(eth(2));
    expect(await str(reward1Adapter.balanceOf(user1))).to.equal(eth(2));

    await reward1Adapter.transfer(user2, eth(2), { from: user1 });
    expect(await str(reward1Wrapper.balanceOf(user2))).to.equal(eth(2));
  });

  it('should let a farmer token be unwrapped down to 0', async () => {
    const wrapperFactory = await WrapperFactory.new();
    const adapterFactory = await YieldAdapterFactory.new('0x0000000000000000000000000000000000000000');
    const factory = await FarmerTokenFactory.new(adapterFactory.address);
    const token = await TestERC20.new();
    const reward1 = await TestERC20.new();

    await wrapperFactory.createWrapper(reward1.address);
    const rewardWrapperAddress = await wrapperFactory.calculateWrapperAddress(reward1.address);

    await factory.createWrapper(token.address, [rewardWrapperAddress]);
    const wrapperAddress = await factory.calculateWrapperAddress(token.address, [rewardWrapperAddress]);
    const farmerToken = await FarmerToken.at(wrapperAddress);
    expect(await farmerToken.rewardTokens()).to.deep.equal([reward1.address]);

    await token.transfer(user1, eth(2), { from: admin });
    await token.approve(wrapperAddress, eth(10), { from: user1 });
    await farmerToken.wrap(eth(2), { from: user1 });

    await reward1.transfer(farmerToken.address, eth(2));
    await farmerToken.harvest(reward1.address);
    expect(await str(farmerToken.rewardBalance(reward1.address, user1))).to.equal(eth(2));

    await farmerToken.unwrap(eth(1), { from: user1 });
    expect(await str(farmerToken.balanceOf(user1))).to.equal(eth(1));
    expect(await str(token.balanceOf(user1))).to.equal(eth(1));
    expect(await str(farmerToken.rewardBalance(reward1.address, user1))).to.equal(eth(2));

    await farmerToken.unwrap(eth(1), { from: user1 });
    expect(await str(farmerToken.balanceOf(user1))).to.equal('0');
    expect(await str(token.balanceOf(user1))).to.equal(eth(2));
    expect(await str(farmerToken.rewardBalance(reward1.address, user1))).to.equal('0');

    await farmerToken.wrap(eth(2), { from: user1 });
    await farmerToken.harvest(reward1.address);
    expect(await str(farmerToken.rewardBalance(reward1.address, user1))).to.equal(eth(2));
  });

  it('should let a farmer token be unwrapped with other users', async () => {
    const wrapperFactory = await WrapperFactory.new();
    const adapterFactory = await YieldAdapterFactory.new('0x0000000000000000000000000000000000000000');
    const factory = await FarmerTokenFactory.new(adapterFactory.address);
    const token = await TestERC20.new();
    const reward1 = await TestERC20.new();

    await wrapperFactory.createWrapper(reward1.address);
    const rewardWrapperAddress = await wrapperFactory.calculateWrapperAddress(reward1.address);

    await factory.createWrapper(token.address, [rewardWrapperAddress]);
    const wrapperAddress = await factory.calculateWrapperAddress(token.address, [rewardWrapperAddress]);
    const farmerToken = await FarmerToken.at(wrapperAddress);
    expect(await farmerToken.rewardTokens()).to.deep.equal([reward1.address]);

    await token.transfer(user1, eth(3), { from: admin });
    await token.approve(wrapperAddress, eth(10), { from: user1 });
    await farmerToken.wrap(eth(3), { from: user1 });

    await reward1.transfer(farmerToken.address, eth(3));
    await farmerToken.harvest(reward1.address);
    expect(await str(farmerToken.rewardBalance(reward1.address, user1))).to.equal(eth(3));

    await farmerToken.transfer(user2, eth(1), { from: user1 });
    expect(await str(farmerToken.rewardBalance(reward1.address, user1))).to.equal(eth(2));
    expect(await str(farmerToken.rewardBalance(reward1.address, user2))).to.equal(eth(1));

    await farmerToken.unwrap(eth(1), { from: user1 });
    expect(await str(farmerToken.balanceOf(user1))).to.equal(eth(1));
    expect(await str(token.balanceOf(user1))).to.equal(eth(1));
    expect(await str(farmerToken.rewardBalance(reward1.address, user1))).to.equal(eth(1.5));
    expect(await str(farmerToken.rewardBalance(reward1.address, user2))).to.equal(eth(1.5));

    await farmerToken.unwrap(eth(1), { from: user1 });
    expect(await str(farmerToken.balanceOf(user1))).to.equal('0');
    expect(await str(token.balanceOf(user1))).to.equal(eth(2));
    expect(await str(farmerToken.rewardBalance(reward1.address, user1))).to.equal('0');
    expect(await str(farmerToken.rewardBalance(reward1.address, user2))).to.equal(eth(3));

    await farmerToken.wrap(eth(2), { from: user1 });
    expect(await str(farmerToken.balanceOf(user1))).to.equal(eth(2));
    expect(await str(farmerToken.balanceOf(user2))).to.equal(eth(1));
    expect(await str(farmerToken.rewardBalance(reward1.address, user1))).to.equal('0');
    expect(await str(farmerToken.rewardBalance(reward1.address, user2))).to.equal(eth(3));

    await reward1.transfer(farmerToken.address, eth(3));
    await farmerToken.harvest(reward1.address);
    expect(await str(farmerToken.rewardBalance(reward1.address, user1))).to.equal(eth(2));
    expect(await str(farmerToken.rewardBalance(reward1.address, user2))).to.equal(eth(4));
  });

  it('should handle remainders well', async function () {
    this.timeout(20000);

    const wrapperFactory = await WrapperFactory.new();
    const adapterFactory = await YieldAdapterFactory.new('0x0000000000000000000000000000000000000000');
    const factory = await FarmerTokenFactory.new(adapterFactory.address);
    const token = await TestERC20.new();
    const reward1 = await TestERC20.new();

    await wrapperFactory.createWrapper(reward1.address);
    const rewardWrapperAddress = await wrapperFactory.calculateWrapperAddress(reward1.address);

    await factory.createWrapper(token.address, [rewardWrapperAddress]);
    const wrapperAddress = await factory.calculateWrapperAddress(token.address, [rewardWrapperAddress]);
    const farmerToken = await FarmerToken.at(wrapperAddress);
    expect(await farmerToken.rewardTokens()).to.deep.equal([reward1.address]);

    await token.transfer(user1, eth(10), { from: admin });
    await token.approve(wrapperAddress, eth(10), { from: user1 });
    await farmerToken.wrap(eth(7), { from: user1 });

    for (let i = 0; i < 100; i++) {
      await reward1.transfer(farmerToken.address, eth(0.1));
      await farmerToken.harvest(reward1.address);
    }

    const finalBalance = await farmerToken.rewardBalance(reward1.address, user1);
    const roundingError = web3.utils.toBN(eth(10)).sub(finalBalance).toNumber();

    expect(roundingError).to.be.lessThan(100000000000);
  });
});
