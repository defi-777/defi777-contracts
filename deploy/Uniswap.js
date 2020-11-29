const uniswapRouter = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';

const uniswapContracts = {
  '1': {
    tokens: [
      '0x6b175474e89094c44da98b954eedeac495271d0f', // Dai
      '0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2', // MKR
      '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984', // UNI
    ],
    pools: [
      '0xbb2b8038a1640196fbe3e38816f3e67cba72d940', // WBTC-ETH
      '0xa478c2975ab1ea89e8196811f51a7b7ade33eb11', // DAI-ETH
      '0xd3d2e2692501a5c9ca623199d38826e513033a17', // UNI-ETH
    ],
  },
  '4': {
    tokens: [
      '0xc7ad46e0b8a400bb3c915120d284aafba8fc4735', // Dai
      '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984', // UNI
    ],
    pools: [
      '0x8b22f85d0c844cf793690f6d9dfe9f11ddb35449', // DAI-ETH
      '0x4e99615101ccbb83a462dc4de2bc1362ef1365e5', // UNI-ETH
    ],
  },
  '42': {
    tokens: [
      '0x4f96fe3b7a6cf9725f59d353f723c1bdb64ca6aa', // Dai
      '0xaaf64bfcc32d0f15873a02163e7e500671a4ffcd', // MKR
      '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984', // UNI
    ],
    pools: [
      '0xb10cf58e08b94480fcb81d341a63295ebb2062c2', // Dai-ETH
      '0x49cc066368d92f7971b1fbb4b84f289b30970d95', // MKR-ETH
      '0xc8828ed8ad6fd765f9b0cc1e140e9a9016a87010', // UNI-ETH
    ],
  },
}

const func = async function ({ deployments, getNamedAccounts, getChainId }) {
  const chainId = await getChainId();
  if (!uniswapContracts[chainId]) {
    console.log(`Uniswap not deployed on chain ${chainId}, skipping`);
    return
  }
  const { tokens, pools } = uniswapContracts[chainId];

  const { deploy, execute, read } = deployments;
  const { deployer } = await getNamedAccounts();

  // Helpers
  const getWrapper = token => read('WrapperFactory', 'calculateWrapperAddress', token);

  const ensureWrapper = async (token) => {
    const wrapper = await getWrapper(token);
    if (await web3.eth.getCode(wrapper) === '0x') {
      await execute('WrapperFactory', {from: deployer}, 'createWrapper', token);
    }
    return wrapper;
  }

  const ensureAdapter = async (factoryName, token) => {
    const adapterAddress = await read(factoryName, 'calculateAdapterAddress', token);
    if (await web3.eth.getCode(adapterAddress) === '0x') {
      await execute(factoryName, {from: deployer}, 'createAdapter', token);
    }
  };

  const adapterFactoryDeployment = await deploy("UniswapAdapterFactory", {
    args: [uniswapRouter],
    from: deployer,
    deterministicDeployment: true,
  });
  console.log(`Deployed UniswapAdapterFactory to ${adapterFactoryDeployment.address}`);

  for (const token of tokens) {
    const wrapper = await ensureWrapper(token);
    await ensureAdapter('UniswapAdapterFactory', wrapper);
  }
  console.log(`Created ${pools.length} swap adapters`);

  const ethAdapterDeployment = await deploy("UniswapETHAdapter", {
    args: [uniswapRouter],
    from: deployer,
    deterministicDeployment: true,
  });
  console.log(`Deployed UniswapETHAdapter to ${ethAdapterDeployment.address}`);

  const poolAdapterFactoryDeployment = await deploy("UniswapPoolAdapterFactory", {
    args: [uniswapRouter],
    from: deployer,
    deterministicDeployment: true,
  });
  console.log(`Deployed UniswapPoolAdapterFactory to ${poolAdapterFactoryDeployment.address}`);

  for (const pool of pools) {
    const poolWrapper = await ensureWrapper(pool);
    await ensureAdapter('UniswapPoolAdapterFactory', poolWrapper);
  }
  console.log(`Created ${pools.length} pool adapters`);
};

module.exports = func;
module.exports.runAtTheEnd = true;
