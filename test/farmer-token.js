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

    const adapterFactory = await YieldAdapterFactory.new('0x0000000000000000000000000000000000000000');
    const factory = await FarmerTokenFactory.new(adapterFactory.address);
    const token = await TestERC20.new();
    const reward1 = await TestERC20.new();

    await factory.createWrapper(token.address);
    const wrapperAddress = await factory.calculateWrapperAddress(token.address);
    const farmerToken = await FarmerToken.at(wrapperAddress);
    await farmerToken.addRewardToken(reward1.address);
    expect(await farmerToken.rewardTokens()).to.deep.equal([reward1.address]);

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
    const factory = await FarmerTokenFactory.new(adapterFactory.address);
    const token = await TestERC20.new();
    const reward1 = await TestERC20.new();

    await wrapperFactory.createWrapper(reward1.address);
    await factory.createWrapper(token.address);
    const wrapperAddress = await factory.calculateWrapperAddress(token.address);
    const farmerToken = await FarmerToken.at(wrapperAddress);
    await farmerToken.addRewardToken(reward1.address);

    const reward1Wrapper = await TestERC20.at(await wrapperFactory.calculateWrapperAddress(reward1.address));
    const reward1Adapter = await TestERC20.at(await adapterFactory.calculateWrapperAddress(wrapperAddress, reward1.address));

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
});
