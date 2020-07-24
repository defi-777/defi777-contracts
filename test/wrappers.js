const { getContract, web3, group, getAccounts, str, eth } = require('./test-lib');
const { singletons, expectRevert } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const TestERC20 = getContract('TestERC20');
const TestUSDC = getContract('TestUSDC');
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

    await factory.create(token.address);
    const wrapperAddress = await factory.getWrapper(token.address);
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

  it('Should wrap an Dai and unwrap it');

  it('Should wrap USDC and unwrap it', async () => {
    const token = await TestUSDC.new();
    const factory = await WrapperFactory.new();

    await factory.create(token.address);
    const wrapperAddress = await factory.getWrapper(token.address);
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

    await factory.createWithName(mkr.address, 'Maker777', 'MKR777');
    const wrapperAddress = await factory.getWrapper(mkr.address);
    const wrapper = await Wrapped777.at(wrapperAddress);
    expect(await wrapper.symbol()).to.equal('MKR777');
  });

  it('should upgrade old 777 tokens', async () => {
    const token = await TestERC20.new();

    const factory1 = await WrapperFactory.new();
    await factory1.create(token.address);
    const wrapper1Address = await factory1.getWrapper(token.address);
    const wrapper1 = await Wrapped777.at(wrapper1Address);

    const factory2 = await WrapperFactory.new();
    await factory2.create(token.address);
    const wrapper2Address = await factory2.getWrapper(token.address);
    const wrapper2 = await Wrapped777.at(wrapper2Address);

    await token.approve(wrapper1Address, eth('10'));
    await wrapper1.wrap(eth('10'));

    await wrapper1.transfer(wrapper2Address, eth('10'));

    expect(await str(wrapper2.balanceOf(defaultSender))).to.equal(eth('10'));

  });

  it('Should issue flash loans', async () => {
    const token = await TestERC20.new();
    const factory = await WrapperFactory.new();

    await factory.create(token.address);
    const wrapperAddress = await factory.getWrapper(token.address);
    const wrapper = await Wrapped777.at(wrapperAddress);

    const tester = await TestFlashLoanRecipient.new();

    const { logs, receipt } = await tester.runFlashLoan(wrapper.address, toWei('10', 'ether'));

    await expectRevert(
      tester.runInvalidFlashLoan(wrapper.address, toWei('10', 'ether')),
      'Flash loan was not returned',
    );
  });

  it('Should set allowance with permit()');
});
