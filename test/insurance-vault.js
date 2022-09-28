const { expect } = require("chai");
const { utils } = require("ethers");
const { ethers } = require("hardhat");

describe.only("Insurance Vault", function () {
  let owner, holder, beneficiary;
  let manager;
  let weth;
  let usdb;
  let usdc;

  beforeEach(async () => {
    [owner, holder, beneficiary] = await ethers.getSigners();

    const InsuranceVaultFactory = await ethers.getContractFactory(
      "InsuranceVault"
    );
    const InsuranceVaultManagerFactory = await ethers.getContractFactory(
      "InsuranceVaultManager"
    );
    const MockERC20Factory = await ethers.getContractFactory("MockERC20");

    weth = await MockERC20Factory.deploy();
    usdb = await MockERC20Factory.deploy();
    usdc = await MockERC20Factory.deploy();

    manager = await InsuranceVaultManagerFactory.deploy(
      weth.address,
      usdb.address,
      usdc.address
    );

    const vault = await InsuranceVaultFactory.deploy();
    await manager.setVaultTemplate(vault.address);
  });

  describe("#createVault", () => {
    it("create new vault", async () => {
      const params = [
        8512232569888,
        ["Thando", "Ngowaza", "17 Pieter Straat, Bloemfontein, 9876"],
        weth.address,
        utils.parseEther("200"),
        true,
        utils.parseEther("100000"),
        731289600,
        0,
      ];

      const tx = await manager.connect(holder).createVault(...params);
      const receipt = await tx.wait();

      expect(await manager.getGeneratedVaultsLength(holder.address)).to.eq(1);
      expect(await manager.holderAddress(params[0])).to.eq(
        receipt.events[0].address
      );
    });
  });

  describe("#checkPolicyStatus", () => {
    let vault;

    beforeEach(async () => {
      const params = [
        8512232569888,
        ["Thando", "Ngowaza", "17 Pieter Straat, Bloemfontein, 9876"],
        weth.address,
        utils.parseEther("200"),
        true,
        utils.parseEther("100000"),
        731289600,
        0,
      ];

      const tx = await manager.connect(holder).createVault(...params);
      const receipt = await tx.wait();

      const InsuranceVaultFactory = await ethers.getContractFactory(
        "InsuranceVault"
      );
      vault = await InsuranceVaultFactory.attach(receipt.events[0].address);
    });

    it("checkPolicyStatus", async () => {
      const response = await vault.checkPolicyStatus();
      expect(response[0]).to.eq(0);
      expect(response[1]).to.eq(0);
    });

    it("checkPolicyStatus when should be suspended", async () => {
      await ethers.provider.send("evm_increaseTime", [86400 * 365 * 25]);
      await ethers.provider.send("evm_mine");

      const response = await vault.checkPolicyStatus();
      expect(response[1]).to.eq(1);
    });
  });
});
