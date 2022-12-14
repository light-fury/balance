import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-gas-reporter";
import "solidity-coverage";
import { HardhatUserConfig, task } from "hardhat/config";

require("@nomiclabs/hardhat-waffle");
import {
  alchemyApiKey,
  privateKey,
  daoPrivateKey,
  etherscanApiKey,
  alchemyApiKeyProd,
  other_privateKey
} from "./secrets.json";
// require('@symblox/hardhat-abi-gen');

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
const config: HardhatUserConfig = {
  typechain: {
    target: "ethers-v5",
  },
  networks: {
    /* hardhat: {
      forking: {
        url: "https://rpc.ftm.tools/",
      },
    }, */
    goerli: {
      url: `https://goerli.infura.io/v3/9156cc61e0b54f2e8063f8fd96da5d76`,
      accounts: [`${privateKey}`, `${other_privateKey}`],
    },
    mainnet: {
      // url: `https://eth-mainnet.alchemyapi.io/v2/${alchemyApiKeyProd}`,
      url: `https://cloudflare-eth.com`,
      accounts: [`${privateKey}`],
    },
    bsc: {
      url: `https://bsc-dataseed.binance.org/`,
      accounts: [`${privateKey}`],
    },
    fantom_testnet: {
      url: `https://rpc.testnet.fantom.network/`,
      accounts: [`${privateKey}`],
    },
    fantom: {
      url: `https://rpc.ftm.tools/`,
      accounts: [`${privateKey}`],
    },
    moonriver: {
      url: `https://rpc.api.moonriver.moonbeam.network`,
      accounts: [`${privateKey}`],
      chainId: 1285,
    },
    moonbase_testnet: {
      url: `https://rpc.testnet.moonbeam.network`,
      accounts: [`${privateKey}`],
      chainId: 1287,
      // gas: 2100000,
      // gasPrice: 8000000000
    },
    avalanche: {
      url: `https://api.avax.network/ext/bc/C/rpc`,
      accounts: [`${privateKey}`],
      chainId: 43114,
    },
    matic: {
      url: `https://rpc-mainnet.maticvigil.com`,
      accounts: [`${privateKey}`],
    },
    // hardhat: {
    //   chainId: 1287
    // },
  },
  solidity: {
    version: "0.8.16",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  mocha: {
    timeout: 0,
  },
  etherscan: {
    apiKey: `${etherscanApiKey}`,
  },
  // abiExporter: {
  //   path: './data/abi',
  //   clear: true,
  //   flat: true,
  //   spacing: 2
  // }
};

export default config;