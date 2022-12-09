import { Contract } from "ethers";
import { ethers } from "hardhat";
import { BinaryMarket, BinaryMarket__factory, BinaryVault, BinaryVault__factory } from "../typechain-types";

async function main() {
    
    // get wallets
    const [owner, operator, treasury] = await ethers.getSigners();
    console.log(owner.address, operator.address, treasury.address);
    const network = "goerli";
    const {daiAddress} = require(`./networks-${network}`);

    // deploy oracle
    const OracleFactory = await ethers.getContractFactory("Oracle");
    const oracle = await OracleFactory.deploy();
    await oracle.deployed();

    // deploy binary config
    const ConfigFactory = await ethers.getContractFactory("BinaryConfig")
    const config = await ConfigFactory.deploy(1000, 86400, treasury.address);
    await config.deployed();

    // deploy binary vault
    const VaultManagerFactory = await ethers.getContractFactory("BinaryVaultManager");
    const vaultManager = await VaultManagerFactory.deploy();
    await vaultManager.deployed();

    const MarketManagerFactory = await ethers.getContractFactory("BinaryMarketManager");
    const marketManager = await MarketManagerFactory.deploy();
    await marketManager.deployed();

    console.log(
        `Binary Market Manager to: ${marketManager.address}`
      );
    console.log(
        `Verify:\nnpx hardhat verify --network ${network} ${marketManager.address}\n`
    );

    console.log(
        `Binary Vault Manager to: ${vaultManager.address}`
    );

    console.log(
        `Verify:\nnpx hardhat verify --network ${network} ${vaultManager.address}\n`
    );

    console.log(
        `Binary Oracle to: ${oracle.address}`
    );

    console.log(
        `Verify:\nnpx hardhat verify --network ${network} ${oracle.address}\n`
    );

    console.log(
        `Binary Config to: ${config.address}`
    );

    console.log(
        `Verify:\nnpx hardhat verify --network ${network} ${config.address}\n`
    );

    console.log("deploying new vault...");
    
    // create new vault
    await vaultManager.connect(owner).createNewVault(
        "Balance BTC/USDC Vault", "BTCUSDC", 0, daiAddress, config.address
    );
      
    const vaultAddress = await vaultManager.vaults(daiAddress);
    
    console.log(
        `Example Vault to: ${vaultAddress}`
    );

    console.log(
        `Verify:\nnpx hardhat verify --network ${network} ${vaultAddress}\n`
    );

    console.log("deploying new market...")
    // create new binary market
    await marketManager.createMarket(
        oracle.address, vaultAddress, "BTC/USDC Market", [{
            id: 0,
            interval: 60, // 60s = 1m,
            intervalBlocks: 10, // 60s means 10 blocks
        }, {
            id: 1,
            interval: 300, // 300s = 5m,
            intervalBlocks: 50,
        }, {
            id: 2,
            interval: 900, // 900s = 15m,
            intervalBlocks: 150
        }], 
        owner.address, operator.address, ethers.utils.parseEther("0.1")
    );

    const marketAddress = (await marketManager.allMarkets(0)).market;

    console.log(
        `Example Market to: ${marketAddress}`
    );

    console.log(
        `Verify:\nnpx hardhat verify --network ${network} ${marketAddress}\n`
    );

    const market = <BinaryMarket>(new Contract(marketAddress, BinaryMarket__factory.abi, owner));
    const vault = <BinaryVault>(new Contract(vaultAddress, BinaryVault__factory.abi, owner));


    await oracle.setWriter(market.address, true);
    await vault.connect(owner).whitelistMarket(market.address, true);
}

main()
  .then(() => process.exit())
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });