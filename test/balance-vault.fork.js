const { ethers } = require("hardhat");

describe("Balance Vault", function () {
  let manager;

  beforeEach(async () => {
    const BalanceVaultManagerFactory = await ethers.getContractFactory(
      "BalanceVaultManager"
    );

    manager = await BalanceVaultManagerFactory.attach(
      "0x60E71c90510EB4983cf0631d3Bd8909d12c0d051"
    );
  });

  it("", async () => {
    const vaults = await manager.getGeneratedVaultsPage(0, 1);
    console.log(vaults);
  });
});
