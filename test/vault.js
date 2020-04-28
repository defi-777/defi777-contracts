const { getContract, web3, group, getAccounts, str } = require('./test-lib');
const { expect } = require('chai');

const TestERC20 = getContract('TestERC20');
const TestVault = getContract('TestVault');

const { toWei } = web3.utils;

const ONE_GWEI = 1000000000;

group('Vault', (accounts) => {
  const [defaultSender, tokenOwner, user, user2] = getAccounts(accounts);

  it('Should deposit, transfer and withdraw a token', async () => {
    const vault = await TestVault.new();
    const token = await TestERC20.new({ from: tokenOwner });

    await token.transfer(vault.address, toWei('2', 'ether'), { from: tokenOwner });

    await vault.testDeposit(token.address, user, { from: tokenOwner });
    expect(await str(vault.testBalanceOf(token.address, user))).to.equal(toWei('2', 'ether'));

    await vault.testTransfer(token.address, user, user2, toWei('0.5', 'ether'), { from: tokenOwner });
    expect(await str(vault.testBalanceOf(token.address, user))).to.equal(toWei('1.5', 'ether'));
    expect(await str(vault.testBalanceOf(token.address, user2))).to.equal(toWei('0.5', 'ether'));

    await vault.testWithdraw(token.address, user2, toWei('0.5', 'ether'), { from: tokenOwner });
    expect(await str(vault.testBalanceOf(token.address, user2))).to.equal(toWei('0', 'ether'));
  });
});
