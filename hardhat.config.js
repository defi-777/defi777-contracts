require('dotenv').config();
require("@nomiclabs/hardhat-truffle5");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-deploy");

task("deployments", "Prints all deployment addresses", async function(_, { deployments }) {
  Object.entries(await deployments.all()).map(([name, metadata]) => {
    console.log(`${name}: ${metadata.address} (${metadata.transactionHash} : ${metadata.receipt && metadata.receipt.blockNumber})`)
  });
});

const SCAN_SIZE = 10000;

task("wrappers", "Prints all deployed wrappers", async function(_, { deployments }) {
  const WrapperFactory = artifacts.require('WrapperFactory');
  const ERC20 = artifacts.require('ERC20');

  const wrapperFactoryDeployment = await deployments.get('WrapperFactory');
  const wrapperFactory = await WrapperFactory.at(wrapperFactoryDeployment.address);
  console.log('== WrapperFactory ==\n====================');

  const now = await web3.eth.getBlockNumber();
  for (let block = wrapperFactoryDeployment.receipt.blockNumber; block < now; block += SCAN_SIZE) {
    const events = await wrapperFactory.getPastEvents('WrapperCreated', { fromBlock: block, toBlock: block + SCAN_SIZE });
    for (event of events) {
      const tokenAddress = event.returnValues.token;
      const wrapperAddress = await wrapperFactory.calculateWrapperAddress(tokenAddress);
      const token = await ERC20.at(tokenAddress);
      console.log(`- ${await token.name()}: ${tokenAddress} => ${wrapperAddress}`);
    }
  }
})

module.exports = {
  networks: {
    hardhat: {
    },
    local: {
      url: 'http://localhost:8545',
    },
    kovan: {
      url: `https://kovan.infura.io/v3/${process.env.INFURA_KEY}`,
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
      gasPrice: 1000000000,
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_KEY}`,
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
      gasPrice: 1000000000,
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_KEY}`,
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
    },
  },

  solidity: {
    version: "0.6.12",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
    },
  },

  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },

  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
};
