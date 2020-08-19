const { getContract, web3, group, getAccounts, str, getDefiAddresses } = require('./test-lib');
const { singletons } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const FarmerToken = getContract('FarmerToken');
const TestERC20 = getContract('TestERC20');

const { toWei, toBN } = web3.utils;
const eth = num => toWei(num, 'ether');

const ONE_GWEI = 1000000000;

group('Farmer Token', (accounts) => {
  const [user1, user2, user3, pool] = getAccounts(accounts);


  before(async () => {
    await singletons.ERC1820Registry(user1);
  });

  it('should allocate tokens correctly', async () => {
    const farmerToken = await FarmerToken.new();

    await farmerToken.mint(eth('2'), { from: user1 });

    await farmerToken.harvest(eth('2'));
    expect(await str(farmerToken.rewardBalance(user1))).to.equal(eth('2'));

    await farmerToken.mint(eth('6'), { from: user2 });

    await farmerToken.harvest(eth('8'));
    expect(await str(farmerToken.rewardBalance(user1))).to.equal(eth('4'));
    expect(await str(farmerToken.rewardBalance(user2))).to.equal(eth('6'));

    await farmerToken.withdraw(eth('2'), { from: user2 });
    expect(await str(farmerToken.rewardBalance(user1))).to.equal(eth('4'));
    expect(await str(farmerToken.rewardBalance(user2))).to.equal(eth('4'));

    await farmerToken.transfer(user3, eth('3'), { from: user2 });
    expect(await str(farmerToken.rewardBalance(user1))).to.equal(eth('4'));
    expect(await str(farmerToken.rewardBalance(user2))).to.equal(eth('2'));
    expect(await str(farmerToken.rewardBalance(user3))).to.equal(eth('2'));

    await farmerToken.harvest(eth('8'));
    await farmerToken.withdraw(eth('4'), { from: user1 });
    expect(await str(farmerToken.rewardBalance(user1))).to.equal(eth('2'));
    expect(await str(farmerToken.rewardBalance(user2))).to.equal(eth('5'));
    expect(await str(farmerToken.rewardBalance(user3))).to.equal(eth('5'));

    await farmerToken.transfer(pool, eth('2'), { from: user1 });
    await farmerToken.transfer(pool, eth('3'), { from: user2 });
    await farmerToken.transfer(pool, eth('3'), { from: user3 });
    expect(await str(farmerToken.rewardBalance(user1))).to.equal('0');
    expect(await str(farmerToken.rewardBalance(user2))).to.equal('0');
    expect(await str(farmerToken.rewardBalance(user3))).to.equal('0');
    expect(await str(farmerToken.rewardBalance(pool))).to.equal(eth('12'));

    await farmerToken.harvest(eth('4'));

    expect(await str(farmerToken.rewardBalance(pool))).to.equal(eth('16'));

    await farmerToken.transfer(user1, eth('2'), { from: pool });
    await farmerToken.transfer(user2, eth('3'), { from: pool });
    await farmerToken.transfer(user3, eth('3'), { from: pool });
    expect(await str(farmerToken.rewardBalance(user1))).to.equal(eth('4'));
    expect(await str(farmerToken.rewardBalance(user2))).to.equal(eth('6'));
    expect(await str(farmerToken.rewardBalance(user3))).to.equal(eth('6'));
  });
});
