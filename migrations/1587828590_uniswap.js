const UniswapWrapperFactory = artifacts.require('UniswapWrapperFactory');

module.exports = function(deployer) {
  deployer.deploy(UniswapWrapperFactory, '0xcDbE04934d89e97a24BCc07c3562DC8CF17d8167');
};
