import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { Contract, utils } from "ethers";
import { Oracle, BinaryConfig, BinaryVault, MockERC20, BinaryMarket, BinaryMarket__factory, BinaryVault__factory } from "../../typechain-types";

export async function marketFixture() {
    let owner: SignerWithAddress;
    let operator: SignerWithAddress;
    let notOperator: SignerWithAddress;
    let treasury: SignerWithAddress;

    let oracle: Oracle;
    let uToken: MockERC20;
    let config: BinaryConfig;
    let vault: BinaryVault;
    let market: BinaryMarket;
    // get wallets
    [owner, operator, notOperator, treasury] = await ethers.getSigners();

    // deploy mock erc20 contract
    const MockERC20 = await ethers.getContractFactory('MockERC20')
    uToken = await MockERC20.deploy();
    await uToken.deployed();

    // deploy oracle
    const OracleFactory = await ethers.getContractFactory("Oracle");
    oracle = await OracleFactory.deploy();
    await oracle.deployed();

    // deploy binary config
    const ConfigFactory = await ethers.getContractFactory("BinaryConfig")
    config = await ConfigFactory.deploy(1000, 86400, treasury.address);
    await config.deployed();

    // deploy binary vault
    const VaultManagerFactory = await ethers.getContractFactory("BinaryVaultManager");
    const vaultManager = await VaultManagerFactory.deploy();
    await vaultManager.deployed();

    await vaultManager.createNewVault(
      "Balance BTC/USDC Vault", "BTCUSDC", 0, uToken.address, config.address
    );
    
    const vaultAddress = await vaultManager.vaults(uToken.address);
    vault = <BinaryVault>(new Contract(vaultAddress, BinaryVault__factory.abi, owner));

    const MarketManagerFactory = await ethers.getContractFactory("BinaryMarketManager");
    const marketManager = await MarketManagerFactory.deploy();
    await marketManager.deployed();

    // deploy binary market
    await marketManager.createMarket(
        oracle.address, vault.address, "BTC/USDC Market", "100", [{
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
        owner.address, operator.address, utils.parseEther("0.1")
    );

    const marketAddress = (await marketManager.allMarkets(0)).market;
    market = <BinaryMarket>(new Contract(marketAddress, BinaryMarket__factory.abi, owner));
    await oracle.setWriter(market.address, true);
    await vault.connect(owner).whitelistMarket(market.address, true);
    await uToken.connect(owner).transfer(vault.address, ethers.utils.parseEther("50"));

    return {owner, operator, notOperator, oracle, uToken, config, vault, market};
}

export async function vaultFixture() {
    let owner: SignerWithAddress;
    let operator: SignerWithAddress;
    let notOperator: SignerWithAddress;
    let treasury: SignerWithAddress;

    let oracle: Oracle;
    let uToken: MockERC20;
    let config: BinaryConfig;
    let uToken_other: MockERC20;

    // get wallets
    [owner, operator, notOperator, treasury] = await ethers.getSigners();

    // deploy mock erc20 contract
    const MockERC20 = await ethers.getContractFactory('MockERC20')
    uToken = await MockERC20.deploy();
    await uToken.deployed();

    // deploy another mock erc20 contract
    uToken_other = await MockERC20.deploy();
    await uToken_other.deployed();

    // deploy oracle
    const OracleFactory = await ethers.getContractFactory("Oracle");
    oracle = await OracleFactory.deploy();
    await oracle.deployed();

    // deploy binary config
    const ConfigFactory = await ethers.getContractFactory("BinaryConfig")
    config = await ConfigFactory.deploy(1000, 86400, treasury.address);
    await config.deployed();

    // deploy binary vault
    const VaultManagerFactory = await ethers.getContractFactory("BinaryVaultManager");
    const vaultManager = await VaultManagerFactory.deploy();
    await vaultManager.deployed();

    // deploy other vault
    const VaultFactory = await ethers.getContractFactory("BinaryVault");
    const other_vault = <BinaryVault>await VaultFactory.deploy(
      "Balance BTC/USDC Vault", "BTCUSDC", 0, uToken.address, config.address, owner.address
    );
    await other_vault.deployed();

    return {owner, operator, notOperator, oracle, uToken, config, vaultManager, uToken_other, other_vault};

}