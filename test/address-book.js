const { getContract, web3, group, getAccounts, str } = require('./test-lib');
const { singletons } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const AddressBook = getContract('AddressBook');
const TestERC20 = getContract('TestERC20');
const WrapperFactory = getContract('WrapperFactory');
const Wrapped777 = getContract('Wrapped777');

group('AddressBook', (accounts) => {
  const [defaultSender, user] = getAccounts(accounts);

  before(() => singletons.ERC1820Registry(defaultSender));

  it('should allow looking up addresses using an addressbook', async () => {
    const token = await TestERC20.new();

    const defaultFactory = await WrapperFactory.new();
    const overrideFactory = await WrapperFactory.new();

    const addressBook = await AddressBook.new(defaultFactory.address);

    const defaultWrapper = await defaultFactory.calculateWrapperAddress(token.address);
    const overrideWrapper = await overrideFactory.calculateWrapperAddress(token.address);

    expect(await str(addressBook.calculateWrapperAddress(token.address))).to.equal(defaultWrapper);

    await addressBook.setEntry(token.address, overrideWrapper);

    expect(await str(addressBook.calculateWrapperAddress(token.address))).to.equal(overrideWrapper);
  });
});
