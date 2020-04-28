const { getContract, web3, group, str } = require('./test-lib');
const { expect } = require('chai');

const TestGranularity = getContract('TestGranularity');

const { toWei } = web3.utils;

const ONE_ETH = toWei('1', 'ether');

group('Granularity', (accounts) => {
  it('18 decimals', async () => {
    const granularity = await TestGranularity.new('18');

    expect(await str(granularity.granularity())).to.equal('1');
    expect(await str(granularity.test777to20(ONE_ETH))).to.equal(ONE_ETH);
    expect(await str(granularity.test20to777(ONE_ETH))).to.equal(ONE_ETH);
  });

  it('6 decimals', async () => {
    const granularity = await TestGranularity.new('6');

    expect(await str(granularity.granularity())).to.equal('1000000000000');
    expect(await str(granularity.test777to20(ONE_ETH))).to.equal('1000000');
    expect(await str(granularity.test20to777('1000000'))).to.equal(ONE_ETH);
  });
});
