const { getContract, web3, group, getAccounts, str } = require('./test-lib');
const { singletons } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const TestERC20 = getContract('TestERC20');
const TestUSDC = getContract('TestUSDC');
const Unwrapper = getContract('Unwrapper');
const WrapperFactory = getContract('WrapperFactory');
const Wrapped777 = getContract('Wrapped777');

const { toWei } = web3.utils;

group('Unwrapper', (accounts) => {
  const [defaultSender, user] = getAccounts(accounts);

  before(() => singletons.ERC1820Registry(defaultSender));

  it('should unwrap an ERC20 token', async () => {
    const token = await TestERC20.new();
    const factory = await WrapperFactory.new();

    await factory.create(token.address);
    const wrapperAddress = await factory.getWrapper(token.address);
    const wrapper = await Wrapped777.at(wrapperAddress);;

    await token.approve(wrapperAddress, toWei('10', 'ether'));
    await wrapper.wrap(toWei('10', 'ether'));

    expect(await str(wrapper.balanceOf(defaultSender))).to.equal(toWei('10', 'ether'));

    const unwrapper = await Unwrapper.new();

    await wrapper.transfer(user, toWei('10', 'ether'));
    await wrapper.transfer(unwrapper.address, toWei('10', 'ether'), { from: user });

    expect(await str(token.balanceOf(user))).to.equal(toWei('10', 'ether'));
  });

  it('should unwrap a token with less than 18 decimals', async () => {
    const token = await TestUSDC.new();
    const factory = await WrapperFactory.new();

    await factory.create(token.address);
    const wrapperAddress = await factory.getWrapper(token.address);
    const wrapper = await Wrapped777.at(wrapperAddress);;

    await token.approve(wrapperAddress, '10000000');
    await wrapper.wrap('10000000');

    expect(await str(wrapper.balanceOf(defaultSender))).to.equal(toWei('10', 'ether'));

    const unwrapper = await Unwrapper.new();

    await wrapper.transfer(user, toWei('10', 'ether'));
    await wrapper.transfer(unwrapper.address, toWei('10', 'ether'), { from: user });

    expect(await str(token.balanceOf(user))).to.equal('10000000');
  });
});
