const func = async function ({ deployments, getNamedAccounts }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const deployment = await deploy("WrapperFactory", {
    from: deployer,
    deterministicDeployment: true,
  });
  console.log(`Deployed WrapperFactory to ${deployment.address}`);
};

module.exports = func;
