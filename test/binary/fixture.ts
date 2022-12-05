import { deployContract } from "ethereum-waffle";
import { ethers, upgrades } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { expect } from "chai";
import { utils } from "ethers";
import { evm_setNextBlockTimestamp } from "../helper";
import { Oracle, BinaryConfig, BinaryVault, MockERC20, BinaryMarket } from "../../typechain-types";

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
    const Config = await ethers.getContractFactory("BinaryConfig")
    config = <BinaryConfig>await upgrades.deployProxy(Config, [1000, 86400, treasury.address]);
    await config.deployed();

    // deploy binary vault
    const VaultFactory = await ethers.getContractFactory("BinaryVault");
    vault = <BinaryVault>await upgrades.deployProxy(VaultFactory, [
      "Balance BTC/USDC Vault", "BTCUSDC", 0, uToken.address, config.address
    ]);
    await vault.deployed();

    // deploy binary market
    const MarketFactory = await ethers.getContractFactory("BinaryMarket");
    market = <BinaryMarket>await upgrades.deployProxy(MarketFactory, [
        oracle.address, vault.address, config.address, "BTC/USDC Market", "100", [{
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
    ]);
    await market.deployed();

    await oracle.setWriter(market.address, true);

    return {owner, operator, notOperator, oracle, uToken, config, vault, market};
}