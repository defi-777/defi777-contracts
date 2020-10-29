const func = async function ({ deployments, getNamedAccounts }) {
  const { deploy, deterministic } = deployments;
  const { deployer } = await getNamedAccounts();

  const { address: factoryAddress } = await deterministic('WrapperFactory', { from: deployer });

  const deployment = await deploy("AddressBook", {
    from: deployer,
    args: [factoryAddress],
    deterministicDeployment: true,
  });
  console.log(`Deployed AddressBook to ${deployment.address}`);
};

module.exports = func;
