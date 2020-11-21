const tokens = {
  '1': [],
  '42': [
    '0x4f96fe3b7a6cf9725f59d353f723c1bdb64ca6aa', // Dai
    '0xaaf64bfcc32d0f15873a02163e7e500671a4ffcd', // MKR
    '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984', // UNI
  ],
};

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
