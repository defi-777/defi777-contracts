const curveContracts = {
  '1': {
    crv: '0xD533a949740bb3306d119CC777fa900bA034cd52',
    tokens: [
      '0x6b175474e89094c44da98b954eedeac495271d0f', // Dai
      '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', // USDC
    ],
    pools: [
      { // y
        lpToken: '0xdf5e0e81dff6faf3a7e52ba697820c5e32d806a8',
        deposit: '0xbbc81d23ea2c3ec7e56d39296f0cbb648873a5d3',
        gague: '0xfa712ee4788c042e2b7bb55e6cb8ec569c4530c1',
      },
      { // 3Pool
        lpToken: '0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490',
        deposit: '0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7',
        gague: '0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A',
      },
    ],
  },
};

const func = async function ({ deployments, getNamedAccounts, getChainId }) {
  const chainId = await getChainId();
  if (!curveContracts[chainId]) {
    console.log(`Curve not deployed on chain ${chainId}, skipping`);
    return
  }
  const { tokens, pools, crv } = curveContracts[chainId];

  const { deploy, execute, read, deterministic } = deployments;
  const { deployer } = await getNamedAccounts();

  // Helpers
  const getWrapper = (token) => read('AddressBook', 'calculateWrapperAddress', token);

  const ensureWrapper = async (token) => {
    const wrapper = await getWrapper(token);
    if (await web3.eth.getCode(wrapper) === '0x') {
      await execute('WrapperFactory', {from: deployer, gasLimit: 5000000}, 'createWrapper', token);
    }
    return wrapper;
  }

  const ensureCRVFarmer = async (token, gague) => {
    let wrapper = await getWrapper(token);
    if (await web3.eth.getCode(wrapper) === '0x') {
      await execute('CRVFarmerTokenFactory', {from: deployer, gasLimit: 9500000}, 'createWrapper', token, gague);

      wrapper = await read('CRVFarmerTokenFactory', 'calculateWrapperAddress', token, gague);
      await execute('AddressBook', { from: deployer }, 'setEntry', token, wrapper);
    }
    return wrapper;
  }

  const curveRegistry = await deploy('CurveRegistry', {
    from: deployer,
    deterministicDeployment: true,
  });
  console.log(`Deployed CurveRegistry to ${curveRegistry.address}`);

  const crvWrapper = await ensureWrapper(crv);
  const { address: yieldAdapterFactory } = await deterministic('YieldAdapterFactory', { from: deployer });

  const crvFarmerTokenFactory = await deploy('CRVFarmerTokenFactory', {
    args: [crvWrapper, yieldAdapterFactory],
    from: deployer,
    deterministicDeployment: true,
  });
  console.log(`Deployed CRVFarmerTokenFactory to ${crvFarmerTokenFactory.address}`);

  // Entry adapters
  for (const { lpToken, deposit, gague } of pools) {
    const storedDepositor = await read('CurveRegistry', 'getDepositorAddress', lpToken);
    if (storedDepositor.toLowerCase() !== deposit.toLowerCase()) {
      await execute('CurveRegistry', { from: deployer }, 'addDepositor', deposit, lpToken);
      console.log(`Set depositor ${deposit} for lpToken ${lpToken}`)
    }

    const wrapper = await ensureCRVFarmer(lpToken, gague);
    
    const inputAdapter = await deploy('CurveAdapter', {
      args: [wrapper, curveRegistry.address],
      from: deployer,
      deterministicDeployment: true,
    });
    console.log(`Deployed CurveAdapter for ${lpToken} to ${inputAdapter.address}`);
  }
  console.log(`Created ${pools.length} entry adapters`);

  // Exit adapters
  for (const token of tokens) {
    const wrapper = await ensureWrapper(token);

    const outputAdapter = await deploy('CurveExitAdapter', {
      args: [wrapper, curveRegistry.address],
      from: deployer,
      deterministicDeployment: true,
    });
    console.log(`Deployed CurveExitAdapter for ${token} to ${outputAdapter.address}`);
  }
  console.log(`Created ${tokens.length} exit adapters`);
};

module.exports = func;
module.exports.runAtTheEnd = true;
