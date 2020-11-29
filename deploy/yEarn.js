const aaveContracts = {
  '1': {
    weth: '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
    vaults: [
      // Dai
      { vault: '0xacd43e627e64355f1861cec6d3a6688b31a6f952', token: '0x6b175474e89094c44da98b954eedeac495271d0f' },
      // USDC
      { vault: '0x597ad1e0c13bfe8025993d9e79c69e1c0233522e', token: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48' },
    ],
  },
}

const func = async function ({ deployments, getNamedAccounts, getChainId }) {
  const chainId = await getChainId();
  if (!aaveContracts[chainId]) {
    console.log(`yEarn not deployed on chain ${chainId}, skipping`);
    return
  }
  const { weth, vaults } = aaveContracts[chainId];

  const { deploy, execute, read } = deployments;
  const { deployer } = await getNamedAccounts();

  const deployment = await deploy("YVaultAdapter", {
    args: [weth, deployer],
    from: deployer,
    deterministicDeployment: true,
  });
  console.log(`Deployed YVaultAdapter to ${deployment.address}`);

  const ensureWrapper = async (token, wrapper) => {
    const wrappedTokenCode = await web3.eth.getCode(wrapper);
    if (wrappedTokenCode === '0x') {
      await execute('WrapperFactory', {from: deployer}, 'createWrapper', token);
    }
  }

  const setWrappedVault = async (token, vault) => {
    const wrappedToken = token === weth ? weth : await read('WrapperFactory', 'calculateWrapperAddress', token);
    const wrappedAToken = await read('WrapperFactory', 'calculateWrapperAddress', vault);

    const current = await read('YVaultAdapter', 'wrappedVaultToWrapper', wrappedAToken);
    if (current.toLowerCase() !== wrappedToken.toLowerCase()) {
      await ensureWrapper(token, wrappedToken);
      await ensureWrapper(vault, wrappedAToken);

      await execute('YVaultAdapter', {from: deployer}, 'setWrappedVault', wrappedToken, wrappedAToken);
    }
  }

  for (const { vault, token } of vaults) {
    await setWrappedVault(token, vault);
  }
  console.log(`Set ${vaults.length} vaults`)
};

module.exports = func;
module.exports.runAtTheEnd = true;
