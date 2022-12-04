import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { expect } from "chai";
import { utils } from "ethers";
import { ethers, upgrades } from "hardhat";
import { BinaryConfig, BinaryVault, MockERC20 } from "../../typechain-types";

describe("Binary Option Trading - Vault", () => {
  let admin: SignerWithAddress;
  let alice: SignerWithAddress;
  let market: SignerWithAddress;
  let treasury: SignerWithAddress;

  let uToken: MockERC20;
  let config: BinaryConfig;
  let vault: BinaryVault;

  before(async () => {
    [admin, alice, market, treasury] = await ethers.getSigners();

    const MockERC20 = await ethers.getContractFactory('MockERC20')
    uToken = await MockERC20.deploy();
    await uToken.deployed();

    const Config = await ethers.getContractFactory("BinaryConfig")
    config = <BinaryConfig>await upgrades.deployProxy(Config, [1000, 86400, treasury.address]);
    await config.deployed();
    await config.setTreasury(treasury.address);
  })
  beforeEach(async () => {
    const VaultFactory = await ethers.getContractFactory("BinaryVault");
    vault = <BinaryVault>await upgrades.deployProxy(VaultFactory, [
      "Balance BTC/USDC Vault", "BTCUSDC", 0, uToken.address, config.address
    ]);
    await vault.deployed();
  })

  describe("Initializing", () => {
    it("should revert deployment when invalid inputs provided", async () => {
      const VaultFactory = await ethers.getContractFactory("BinaryVault");
      await expect(
        upgrades.deployProxy(VaultFactory, [
          "Balance BTC/USDC Vault", "BTCUSDC", 0, ethers.constants.AddressZero, config.address
        ])
      ).to.be.revertedWith("ZERO_ADDRESS");

      await expect(
        upgrades.deployProxy(VaultFactory, [
          "Balance BTC/USDC Vault", "BTCUSDC", 0, uToken.address, ethers.constants.AddressZero
        ])
      ).to.be.revertedWith("ZERO_ADDRESS");
    })

    it("should be able to deploy vault contract with valid inputs", async () => {
      const VaultFactory = await ethers.getContractFactory("BinaryVault");
      const vault = <BinaryVault>await upgrades.deployProxy(VaultFactory, [
        "Balance BTC/USDC Vault", "BTCUSDC", 0, uToken.address, config.address
      ]);

      expect(await vault.underlyingToken()).to.be.equal(uToken.address);
      expect(await vault.config()).to.be.equal(config.address);
      expect(await vault.vaultId()).to.be.equal(0);
    })
  })

  describe("Owner", () => {
    it("should be able to pause the vault", async () => {
      expect(await vault.paused()).to.be.false;

      await expect(
        vault.connect(alice).pauseVault()
      ).to.be.revertedWith("Ownable: caller is not the owner");

      await vault.pauseVault();
      expect(await vault.paused()).to.be.true;
    })
    it("should be able to unpause the vault", async () => {
      await vault.pauseVault();
      expect(await vault.paused()).to.be.true;

      await expect(
        vault.connect(alice).unpauseVault()
      ).to.be.revertedWith("Ownable: caller is not the owner");

      await vault.unpauseVault();
      expect(await vault.paused()).to.be.false;
    })
    it("should be able to whitelist/blacklist market", async () => {
      expect(await vault.whitelistedMarkets(market.address)).to.be.false;

      await expect(
        vault.connect(alice).whitelistMarket(market.address, true)
      ).to.be.revertedWith("Ownable: caller is not the owner");

      await expect(
        vault.whitelistMarket(ethers.constants.AddressZero, true)
      ).to.be.revertedWith("ZERO_ADDRESS");

      await vault.whitelistMarket(market.address, true);
      expect(await vault.whitelistedMarkets(market.address)).to.be.true;
    })
  })
  describe("Liquidity - Stake", async () => {
    const stakeAmount = utils.parseEther("100");
    beforeEach(async () => {
      await uToken.transfer(alice.address, stakeAmount);
      await uToken.connect(alice).approve(vault.address, stakeAmount);
    })

    it("should revert staking when invalid inputs provided", async () => {
      await expect(
        vault.connect(alice).stake(ethers.constants.AddressZero, stakeAmount)
      ).to.be.revertedWith("ZERO_ADDRESS");

      await expect(
        vault.connect(alice).stake(alice.address, 0)
      ).to.be.revertedWith("ZERO_AMOUNT");
    })
    it("should revert staking when the vault is paused", async () => {
      await vault.pauseVault();
      await expect(
        vault.connect(alice).stake(alice.address, stakeAmount)
      ).to.be.revertedWith("Pausable: paused");
    })
    it("should be able to stake underlying tokens", async () => {
      const beforeBalance = await uToken.balanceOf(alice.address);
      await expect(
        vault.connect(alice).stake(alice.address, stakeAmount)
      ).to.be.emit(vault, "Staked").withArgs(
        alice.address, 0, stakeAmount
      );
      const afterBalance = await uToken.balanceOf(alice.address);

      expect(beforeBalance.sub(afterBalance)).to.be.equal(stakeAmount);
      expect(await uToken.balanceOf(vault.address)).to.be.equal(stakeAmount);

      const tokenIds = await vault.tokensOfOwner(alice.address);
      expect(tokenIds.length).to.be.equal(1);
      expect(tokenIds[0]).to.be.equal(0);

      expect(await vault.totalStaked()).to.be.equal(stakeAmount);
      expect(await vault.watermark()).to.be.equal(stakeAmount);
      expect(await vault.stakedAmounts(tokenIds[0])).to.be.equal(stakeAmount);
    })

    it("should burn prev token and mint new one", async () => {
      await vault.connect(alice).stake(alice.address, stakeAmount)

      let tokenIds = await vault.tokensOfOwner(alice.address);
      expect(tokenIds.length).to.be.equal(1);
      expect(tokenIds[0]).to.be.equal(0);

      await uToken.connect(alice).approve(vault.address, stakeAmount);
      await vault.connect(alice).stake(alice.address, stakeAmount);

      tokenIds = await vault.tokensOfOwner(alice.address);
      expect(tokenIds.length).to.be.equal(1);
      expect(tokenIds[0]).to.be.equal(1); // tokenId increased

      expect(await vault.totalStaked()).to.be.equal(stakeAmount.mul(2));
      expect(await vault.watermark()).to.be.equal(stakeAmount.mul(2));
      expect(await vault.stakedAmounts(tokenIds[0])).to.be.equal(stakeAmount.mul(2));
    })
  })

  describe("Liquidity - Unstake", () => {
    const stakeAmount = utils.parseEther("1");
    beforeEach(async () => {
      await uToken.approve(vault.address, stakeAmount);
      await vault.stake(admin.address, stakeAmount);
    })

    it("should revert unstaking when invalid inputs provided", async () => {
      await expect(
        vault.unstake(admin.address, 0)
      ).to.be.revertedWith("ZERO_AMOUNT");
      await expect(
        vault.unstake(ethers.constants.AddressZero, stakeAmount)
      ).to.be.revertedWith("ZERO_ADDRESS");
    })
    it("should revert unstaking when the vault is paused", async () => {
      await vault.pauseVault();
      await expect(
        vault.unstake(admin.address, stakeAmount)
      ).to.be.revertedWith("Pausable: paused");
    })
    it("should revert when there is no holding NFTs", async () => {
      await expect(
        vault.connect(alice).unstake(alice.address, stakeAmount)
      ).to.be.revertedWith(`NO_DEPOSIT("${alice.address}")`);
    })
    it("should approve NFTs first before unstake", async () => {
      const balance = await vault.balanceOf(admin.address);
      expect(balance).to.be.equal(1);
      await expect(
        vault.connect(alice).unstake(admin.address, stakeAmount)
      ).to.be.revertedWith("TransferCallerNotOwnerNorApproved");
    })
    it("should revert when unstaking amount greater than deposited amount", async () => {
      const tokenIds = await vault.tokensOfOwner(admin.address);
      const stakedBalance = await vault.stakedAmounts(tokenIds[0]);
      await expect(
        vault.unstake(admin.address, stakedBalance.mul(2))
      ).to.be.revertedWith("EXCEED_BALANCE");
    })
    it("should burn NFTs and mint new one when there is some left", async () => {
      let tokenIds = await vault.tokensOfOwner(admin.address);
      expect(tokenIds.length).to.be.equal(1);

      const beforeBalance = await uToken.balanceOf(admin.address);
      const stakedBalance = await vault.stakedAmounts(tokenIds[0]);
      await expect(
        vault.unstake(admin.address, stakedBalance.div(2))
      ).to.be.emit(vault, "Unstaked").withArgs(admin.address, stakedBalance.div(2));
      const afterBalance = await uToken.balanceOf(admin.address);

      expect(afterBalance.sub(beforeBalance)).to.be.equal(stakedBalance.div(2));

      tokenIds = await vault.tokensOfOwner(admin.address);
      expect(tokenIds.length).to.be.equal(1);

      expect(await vault.totalStaked()).to.be.equal(stakedBalance.div(2));
      expect(await vault.watermark()).to.be.equal(stakedBalance.div(2));
      expect(await vault.stakedAmounts(tokenIds[0])).to.be.equal(stakedBalance.div(2));
    })
    it("should burn NFTs when unstake all", async () => {
      let tokenIds = await vault.tokensOfOwner(admin.address);
      expect(tokenIds.length).to.be.equal(1);

      const beforeBalance = await uToken.balanceOf(admin.address);
      const stakedBalance = await vault.stakedAmounts(tokenIds[0]);
      await expect(
        vault.unstake(admin.address, stakedBalance)
      ).to.be.emit(vault, "Unstaked").withArgs(admin.address, stakedBalance);
      const afterBalance = await uToken.balanceOf(admin.address);

      expect(afterBalance.sub(beforeBalance)).to.be.equal(stakedBalance);

      tokenIds = await vault.tokensOfOwner(admin.address);
      expect(tokenIds.length).to.be.equal(0);

      expect(await vault.totalStaked()).to.be.equal(0);
      expect(await vault.watermark()).to.be.equal(0);
    })
  })

})