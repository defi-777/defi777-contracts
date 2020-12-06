const aaveContracts = {
  '1': {
    addressProvider: '0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5',
    weth: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
    aWeth: '0x030bA81f1c18d280636F32af80b9AAd02Cf0854e',
    aTokens: [
      // Dai
      { aToken: '0x028171bCA77440897B824Ca71D1c56caC55b68A3', token: '0x6B175474E89094C44Da98b954EedeAC495271d0F' },
      // USDC
      { aToken: '0xBcca60bB61934080951369a648Fb03DF4F96263C', token: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48' },
    ],
  },
  '42': {
    addressProvider: '0x652B2937Efd0B5beA1c8d54293FC1289672AFC6b',
    weth: '0xd0a1e359811322d97991e03f863a0c30c2cf029c',
    aWeth: '0xe2735Adf49D06fBC2C09D9c0CFfbA5EF5bA35649',
    aTokens: [
      // Dai
      { aToken: '0x6dDFD6364110E9580292D9eCC745F75deA7e72c8', token: '0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD' },
      // USDC
      { aToken: '0x32A4f93ffbb63213fB8c57b0b0E8Ea09698F3741', token: '0xe22da380ee6B445bb8273C81944ADEB6E8450422' },
    ],
  },
}

const func = async function ({ deployments, getNamedAccounts, getChainId }) {
  const chainId = await getChainId();
  if (!aaveContracts[chainId]) {
    console.log(`Aave not deployed on chain ${chainId}, skipping`);
    return
  }
  const { addressProvider, weth, aTokens, aWeth } = aaveContracts[chainId];

  const { deploy, execute, read } = deployments;
  const { deployer } = await getNamedAccounts();

  const deployment = await deploy("AaveAdapter", {
    args: [addressProvider, weth],
    from: deployer,
    deterministicDeployment: true,
  });
  console.log(`Deployed AaveAdapter to ${deployment.address}`);

  const ensureWrapper = async (token, wrapper) => {
    const wrappedTokenCode = await web3.eth.getCode(wrapper);
    if (wrappedTokenCode === '0x') {
      await execute('WrapperFactory', {from: deployer}, 'createWrapper', token);
    }
  }

  const setWrappedAToken = async (token, aToken) => {
    const wrappedToken = token === weth ? weth : await read('WrapperFactory', 'calculateWrapperAddress', token);
    const wrappedAToken = await read('WrapperFactory', 'calculateWrapperAddress', aToken);

    const current = await read('AaveAdapter', 'wrappedATokenToWrapper', wrappedAToken);
    if (current.toLowerCase() !== wrappedToken.toLowerCase()) {
      await ensureWrapper(token, wrappedToken);
      await ensureWrapper(aToken, wrappedAToken);

      await execute('AaveAdapter', {from: deployer}, 'setWrappedAToken', wrappedToken, wrappedAToken);
    }
  }

  if (aWeth) {
    await setWrappedAToken(weth, aWeth);
  }
  for (const { aToken, token } of aTokens) {
    await setWrappedAToken(token, aToken);
  }
  console.log(`Set ${aTokens.length + !!aWeth} aTokens`)
};

module.exports = func;
module.exports.runAtTheEnd = true;
