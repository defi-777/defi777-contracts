const WrapperFactory = artifacts.require('WrapperFactory');

module.exports = function(deployer) {
  deployer.deploy(WrapperFactory);
};
