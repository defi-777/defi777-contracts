const { getContract, web3, group, getAccounts, str } = require('./test-lib');
const { singletons } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const TestERC20 = getContract('TestERC20');
const Vault = getContract('Vault');

const { toWei } = web3.utils;

const ONE_GWEI = 1000000000;

group('Vault', (accounts) => {
  const [defaultSender, tokenOwner, user, user2] = getAccounts(accounts);

  it('Should deposit, transfer and withdraw a token', async () => {
    const vault = await Vault.new();
    const token = await TestERC20.new({ from: tokenOwner });
    await vault.setAuthorized(tokenOwner, token.address);

    await token.transfer(vault.address, toWei('2', 'ether'), { from: tokenOwner });

    await vault.deposit(token.address, user, { from: tokenOwner });
    expect(await str(vault.balanceOf(token.address, user))).to.equal(toWei('2', 'ether'));

    await vault.transfer(token.address, user, user2, toWei('0.5', 'ether'), { from: tokenOwner });
    expect(await str(vault.balanceOf(token.address, user))).to.equal(toWei('1.5', 'ether'));
    expect(await str(vault.balanceOf(token.address, user2))).to.equal(toWei('0.5', 'ether'));

    await vault.withdraw(token.address, user2, toWei('0.5', 'ether'), { from: tokenOwner });
    expect(await str(vault.balanceOf(token.address, user2))).to.equal(toWei('0', 'ether'));
  });
});
