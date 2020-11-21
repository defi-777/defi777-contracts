const func = async function ({ deployments, getNamedAccounts }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const yieldAdapterDeployment = await deploy("YieldAdapterFactory", {
    from: deployer,
    deterministicDeployment: true,
  });
  console.log(`Deployed YieldAdapterFactory to ${yieldAdapterDeployment.address}`);

  const farmerFactoryDeployment = await deploy("FarmerTokenFactory", {
    args: [yieldAdapterDeployment.address],
    from: deployer,
    deterministicDeployment: true,
  });
  console.log(`Deployed FarmerTokenFactory to ${farmerFactoryDeployment.address}`);
};

module.exports = func;
