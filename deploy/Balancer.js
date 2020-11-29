const balancerContracts = {
  '1': {
    weth: '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
    bal: '0xba100000625a3754423978a60c9317c58a424e3d',
    tokens: [
      '0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9', // AAVE
    ],
    pools: [
      '0x4ea237942e52c7095db7acf244e55decf3ad7371', // LINK-YFI-AAVE-WETH-MKR-BAT-SNX
      '0x7c90a3cd7ec80dd2f633ed562480abbeed3be546', //AAVE-WETH
    ],
  },
  '4': {
    weth: '0xc778417e063141139fce010982780140aa0cd5ab',
    tokens: [
      '0xc7ad46e0b8a400bb3c915120d284aafba8fc4735', // Dai
      '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984', // UNI
    ],
    pools: [
      '0x9743C69c4f95daeeAA054E273F48297983FBDe60', // WETH-DAI-UNI
    ],
  },
  '42': {
    weth: '0xd0a1e359811322d97991e03f863a0c30c2cf029c',
    bal: '0xa332eb80abde13f0073c04a4a9e7522ef8433bbf',
    tokens: [
      '0x4f96fe3b7a6cf9725f59d353f723c1bdb64ca6aa', // Dai
      '0xaaf64bfcc32d0f15873a02163e7e500671a4ffcd', // MKR
    ],
    pools: [
      '0x31670617b85451e5e3813e50442eed3ce3b68d19', // ETH-Dai-MKR
      '0x8aeaadd06c633a75d3e830aa0bd1c51373c4afb7', // ETH-BAL
    ],
  },
}

const func = async function ({ deployments, getNamedAccounts, getChainId }) {
  const chainId = await getChainId();
  if (!balancerContracts[chainId]) {
    console.log(`Balancer not deployed on chain ${chainId}, skipping`);
    return
  }
  const { tokens, pools, weth, bal } = balancerContracts[chainId];

  const { deploy, execute, read } = deployments;
  const { deployer } = await getNamedAccounts();

  // Helpers
  const getWrapper = (token, bal) => read(bal ? 'FarmerTokenFactory' : 'WrapperFactory', 'calculateWrapperAddress', ...(bal ? [token, [bal]] : [token]));

  const ensureWrapper = async (token, bal) => {
    const wrapper = await getWrapper(token, bal);
    if (await web3.eth.getCode(wrapper) === '0x') {
      const args = bal ? [token, [bal]] : [token];
      const result = await execute(bal ? 'FarmerTokenFactory' : 'WrapperFactory', {from: deployer, gasLimit: 9500000}, 'createWrapper', ...args);
    }
    return wrapper;
  }

  const ensureAdapter = async (factoryName, token) => {
    const adapterAddress = await read(factoryName, 'calculateAdapterAddress', token);
    if (await web3.eth.getCode(adapterAddress) === '0x') {
      await execute(factoryName, {from: deployer}, 'createAdapter', token);
    }
  };

  const balWrapper = bal ? await ensureWrapper(bal) : null;

  const adapterFactoryDeployment = await deploy("BalancerPoolFactory", {
    args: [weth],
    from: deployer,
    deterministicDeployment: true,
  });
  console.log(`Deployed BalancerPoolFactory to ${adapterFactoryDeployment.address}`);

  for (const pool of pools) {
    const wrapper = await ensureWrapper(pool, balWrapper);
    await ensureAdapter('BalancerPoolFactory', wrapper);
  }
  console.log(`Created ${pools.length} pool adapters`);

  const ethAdapterDeployment = await deploy("BalancerPoolETHExitAdapter", {
    args: [weth],
    from: deployer,
    deterministicDeployment: true,
  });
  console.log(`Deployed BalancerPoolETHExitAdapter to ${ethAdapterDeployment.address}`);

  const poolAdapterFactoryDeployment = await deploy("BalancerPoolExitFactory", {
    from: deployer,
    deterministicDeployment: true,
  });
  console.log(`Deployed BalancerPoolExitFactory to ${poolAdapterFactoryDeployment.address}`);

  for (const token of tokens) {
    const wrapper = await ensureWrapper(token);
    await ensureAdapter('BalancerPoolExitFactory', wrapper);
  }
  console.log(`Created ${tokens.length} exit adapters`);
};

module.exports = func;
module.exports.runAtTheEnd = true;
