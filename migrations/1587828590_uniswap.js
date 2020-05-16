const UniswapWrapperFactory = artifacts.require('UniswapWrapperFactory');

const uniswapRouterAddress = {
  kovan: '0xcDbE04934d89e97a24BCc07c3562DC8CF17d8167',
};

module.exports = function(deployer, network) {
  deployer.deploy(UniswapWrapperFactory, uniswapRouterAddress[network]);
};
