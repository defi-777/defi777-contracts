const compoundContracts = {
  '1': {
    comp: '0xc00e94cb662c3520282e6f5717214004a7f26888',
    cETH: '0x4ddc2d193948926d02f9b1fe9e1daa0718270ed5',
    cTokens: [
      // Dai
      { cToken: '0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643', token: '0x6B175474E89094C44Da98b954EedeAC495271d0F' },
      // USDC
      { cToken: '0x39aa39c021dfbae8fac545936693ac917d5e7563', token: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48' },
    ],
  },
  '42': {
    comp: '0x61460874a7196d6a22d1ee4922473664b3e95270',
    cETH: '0x41b5844f4680a8c38fbb695b7f9cfd1f64474a72',
    cTokens: [
      // Dai
      { cToken: '0xf0d0eb522cfa50b716b3b1604c4f0fa6f04376ad', token: '0x4f96fe3b7a6cf9725f59d353f723c1bdb64ca6aa' },
    ],
  },
}

const ETHER = '0x0000000000000000000000000000000000000001';

const func = async function ({ deployments, getNamedAccounts, getChainId }) {
  const chainId = await getChainId();
  if (!compoundContracts[chainId]) {
    console.log(`Compound not deployed on chain ${chainId}, skipping`);
    return
  }
  const { cTokens, cETH, comp } = compoundContracts[chainId];

  const { deploy, execute, read } = deployments;
  const { deployer } = await getNamedAccounts();

  const deployment = await deploy("CompoundAdapter", {
    from: deployer,
    deterministicDeployment: true,
  });
  console.log(`Deployed CompoundAdapter to ${deployment.address}`);

  // Helpers
  const getWrapper = (token, _comp) => read(_comp ? 'FarmerTokenFactory' : 'WrapperFactory', 'calculateWrapperAddress', ...(_comp ? [token, [_comp]] : [token]));

  const ensureWrapper = async (token, _comp) => {
    const wrapper = await getWrapper(token, _comp);
    if (await web3.eth.getCode(wrapper) === '0x') {
      const args = _comp ? [token, [_comp]] : [token];
      const result = await execute(_comp ? 'FarmerTokenFactory' : 'WrapperFactory', {from: deployer, gasLimit: 9500000}, 'createWrapper', ...args);
    }
    return wrapper;
  }

  const compWrapper = comp ? await ensureWrapper(comp) : null;

  const setWrappedCToken = async (token, cToken) => {
    const wrappedToken = token === ETHER ? ETHER : await ensureWrapper(token);
    const wrappedCToken = await ensureWrapper(cToken, compWrapper);

    const current = await read('CompoundAdapter', 'wrappedCTokenToWrapper', wrappedCToken);
    if (current.toLowerCase() !== wrappedToken.toLowerCase()) {
      await execute('CompoundAdapter', {from: deployer}, 'setWrappedCToken', wrappedToken, wrappedCToken);
    }
  }

  if (cETH) {
    await setWrappedCToken(ETHER, cETH);
  }
  for (const { cToken, token } of cTokens) {
    await setWrappedCToken(token, cToken);
  }
  console.log(`Set ${cTokens.length + !!cETH} cTokens`)
};

module.exports = func;
module.exports.runAtTheEnd = true;
