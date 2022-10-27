import { utils } from "ethers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { InsuranceVaultManager, MockERC20 } from "../typechain-types";

describe("Insurance Vault", function () {
  let owner: SignerWithAddress;
  let holder: SignerWithAddress;
  let manager: InsuranceVaultManager;
  let usdb: MockERC20;

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
      const params: any[] = [
        "8512232569888",
        ["Thando", "Ngowaza", "17 Pieter Straat, Bloemfontein, 9876"],
        utils.parseEther("200"),
        true,
        utils.parseEther("100000"),
        731289600,
      ];

      const tx = await manager.connect(holder).createVault(
        params[0],
        params[1],
        params[2],
        params[3],
        params[4],
        params[5],
      );
      const receipt = await tx.wait();

      expect(await manager.getGeneratedVaultsLength(holder.address)).to.eq(1);
      if (receipt.events) {
        expect(await manager.holderAddress(params[0])).to.eq(
          receipt.events[0].address
        );
      }
    });
  });
});
