const { getContract, web3, group, getAccounts, str, eth } = require('./test-lib');
const { singletons, expectRevert } = require('@openzeppelin/test-helpers');
const { signDaiPermit, signERC2612Permit } = require('eth-permit');
const { expect } = require('chai');

const MaliciousUpgradeToken = getContract('MaliciousUpgradeToken');
const TestERC20 = getContract('TestERC20');
const TestERC2612 = getContract('TestERC2612');
const TestUSDC = getContract('TestUSDC');
const TestDai = getContract('TestDai');
const TestFlashLoanRecipient = getContract('TestFlashLoanRecipient');
const TestMKR = getContract('TestMKR');
const WrapperFactory = getContract('WrapperFactory');
const Wrapped777 = getContract('Wrapped777');

const { toWei } = web3.utils;

group('Wrapped777', (accounts) => {
  const [defaultSender, user] = getAccounts(accounts);

  before(() => singletons.ERC1820Registry(defaultSender));

  it('Should wrap an ERC20 token and unwrap it', async () => {
    const token = await TestERC20.new();
    const factory = await WrapperFactory.new();

    await factory.createWrapper(token.address);
    const wrapperAddress = await factory.calculateWrapperAddress(token.address);
    const wrapper = await Wrapped777.at(wrapperAddress);

    expect(await str(token.balanceOf(defaultSender))).to.equal(toWei('100', 'ether'));
    expect(await str(wrapper.balanceOf(defaultSender))).to.equal('0');

    await token.approve(wrapperAddress, toWei('10', 'ether'));
    await wrapper.wrap(toWei('10', 'ether'));

    expect(await str(token.balanceOf(defaultSender))).to.equal(toWei('90', 'ether'));
    expect(await str(wrapper.balanceOf(defaultSender))).to.equal(toWei('10', 'ether'));

    await wrapper.transfer(user, toWei('10', 'ether'));
    await wrapper.transfer(wrapper.address, toWei('10', 'ether'), { from: user });

    expect(await str(token.balanceOf(user))).to.equal(toWei('10', 'ether'));
  });

  it('shold wrap an ERC20 using permit', async () => {
    const token = await TestERC2612.new();
    const factory = await WrapperFactory.new();

    await factory.createWrapper(token.address);
    const wrapperAddress = await factory.calculateWrapperAddress(token.address);
    const wrapper = await Wrapped777.at(wrapperAddress);

    expect(await str(token.balanceOf(defaultSender))).to.equal(toWei('100', 'ether'));
    expect(await str(wrapper.balanceOf(defaultSender))).to.equal('0');

    const result = await signERC2612Permit(web3.currentProvider, token.address, defaultSender, wrapper.address, eth('10'));
    await wrapper.wrapWithPermit(eth('10'), result.deadline, result.nonce, result.v, result.r, result.s);

    expect(await str(token.balanceOf(defaultSender))).to.equal(toWei('90', 'ether'));
    expect(await str(wrapper.balanceOf(defaultSender))).to.equal(toWei('10', 'ether'));
  });

  it('Should wrap an Dai and unwrap it', async () => {
    const token = await TestDai.new();
    const factory = await WrapperFactory.new();

    await factory.createWrapper(token.address);
    const wrapperAddress = await factory.calculateWrapperAddress(token.address);
    const wrapper = await Wrapped777.at(wrapperAddress);

    expect(await str(token.balanceOf(defaultSender))).to.equal(toWei('100', 'ether'));
    expect(await str(wrapper.balanceOf(defaultSender))).to.equal('0');

    const result = await signDaiPermit(web3.currentProvider, token.address, defaultSender, wrapper.address);
    await wrapper.wrapWithPermit(eth('10'), result.expiry, result.nonce, result.v, result.r, result.s);

    expect(await str(token.balanceOf(defaultSender))).to.equal(toWei('90', 'ether'));
    expect(await str(wrapper.balanceOf(defaultSender))).to.equal(toWei('10', 'ether'));
  });

  it('Should wrap USDC and unwrap it', async () => {
    const token = await TestUSDC.new();
    const factory = await WrapperFactory.new();

    await factory.createWrapper(token.address);
    const wrapperAddress = await factory.calculateWrapperAddress(token.address);
    const wrapper = await Wrapped777.at(wrapperAddress);

    expect(await str(token.balanceOf(defaultSender))).to.equal('100000000');
    expect(await str(wrapper.balanceOf(defaultSender))).to.equal('0');

    await token.approve(wrapperAddress, '10000000');
    await wrapper.wrap('10000000');

    expect(await str(token.balanceOf(defaultSender))).to.equal('90000000');
    expect(await str(wrapper.balanceOf(defaultSender))).to.equal(toWei('10', 'ether'));

    await wrapper.transfer(user, toWei('10', 'ether'));
    await wrapper.transfer(wrapper.address, toWei('10', 'ether'), { from: user });

    expect(await str(token.balanceOf(user))).to.equal('10000000');
  });

  it('Should wrap MKR and other tokens using bytes32 names', async () => {
    const mkr = await TestMKR.new();
    const factory = await WrapperFactory.new();

    await factory.createWrapper(mkr.address);
    const wrapperAddress = await factory.calculateWrapperAddress(mkr.address);
    const wrapper = await Wrapped777.at(wrapperAddress);
    expect(await wrapper.symbol()).to.equal('MKR777');
  });

  it('should upgrade old 777 tokens', async () => {
    const token = await TestERC20.new();

    const factory1 = await WrapperFactory.new();
    await factory1.createWrapper(token.address);
    const wrapper1Address = await factory1.calculateWrapperAddress(token.address);
    const wrapper1 = await Wrapped777.at(wrapper1Address);

    const factory2 = await WrapperFactory.new();
    await factory2.createWrapper(token.address);
    const wrapper2Address = await factory2.calculateWrapperAddress(token.address);
    const wrapper2 = await Wrapped777.at(wrapper2Address);

    await token.approve(wrapper1Address, eth('10'));
    await wrapper1.wrap(eth('10'));

    await wrapper1.transfer(wrapper2Address, eth('10'));

    expect(await str(wrapper2.balanceOf(defaultSender))).to.equal(eth('10'));
  });

  it('should not allow fake tokens to execute upgrades', async () => {
    const token = await TestERC20.new();
    const fakeToken = await MaliciousUpgradeToken.new(token.address);

    const factory = await WrapperFactory.new();
    await factory.createWrapper(token.address);
    const wrapperAddress = await factory.calculateWrapperAddress(token.address);
    const wrapper = await Wrapped777.at(wrapperAddress);

    await token.approve(wrapperAddress, eth('10'));
    await wrapper.wrap(eth('10'));

    await expectRevert(fakeToken.callReceiveHook(wrapperAddress), 'NO-UPGRADE');
  });

  it('Should issue flash loans', async () => {
    const token = await TestERC20.new();
    const factory = await WrapperFactory.new();

    await factory.createWrapper(token.address);
    const wrapperAddress = await factory.calculateWrapperAddress(token.address);
    const wrapper = await Wrapped777.at(wrapperAddress);

    const tester = await TestFlashLoanRecipient.new();

    const { logs, receipt } = await tester.runFlashLoan(wrapper.address, toWei('10', 'ether'));

    await expectRevert(
      tester.runInvalidFlashLoan(wrapper.address, toWei('10', 'ether')),
      'FLASH-FAIL',
    );
  });

  it('Should set allowance with permit()');
});
