const { expect } = require("chai");
const { utils } = require("ethers");
const { ethers } = require("hardhat");

describe("Insurance Vault", function () {
  let owner, holder;
  let manager;
  let usdb;

  beforeEach(async () => {
    [owner, holder] = await ethers.getSigners();

    const InsuranceVaultFactory = await ethers.getContractFactory(
      "InsuranceVault"
    );
    const InsuranceVaultManagerFactory = await ethers.getContractFactory(
      "InsuranceVaultManager"
    );
    const MockERC20Factory = await ethers.getContractFactory("MockERC20");
    usdb = await MockERC20Factory.deploy();

    manager = await InsuranceVaultManagerFactory.deploy(usdb.address);

    const vault = await InsuranceVaultFactory.deploy();
    await manager.setVaultTemplate(vault.address);
  });

  describe("#createVault", () => {
    it("create new vault", async () => {
      const params = [
        "8512232569888",
        ["Thando", "Ngowaza", "17 Pieter Straat, Bloemfontein, 9876"],
        utils.parseEther("200"),
        true,
        utils.parseEther("100000"),
        731289600,
      ];

      const tx = await manager.connect(holder).createVault(...params);
      const receipt = await tx.wait();

      expect(await manager.getGeneratedVaultsLength(holder.address)).to.eq(1);
      expect(await manager.holderAddress(params[0])).to.eq(
        receipt.events[0].address
      );
    });
  });
});
