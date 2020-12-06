const func = async function ({ deployments, getNamedAccounts }) {
  const { deployer } = await getNamedAccounts();

  const deployment = await deployments.deploy('Unwrapper', {
    from: deployer,
    deterministicDeployment: true,
  });
  console.log(`Deployed Unwrapper to ${deployment.address}`);
};

module.exports = func;
