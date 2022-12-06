import { expect } from "chai";
import { loadFixture } from "ethereum-waffle";
import { Contract, ethers } from "ethers";
import { BinaryVault, BinaryVault__factory } from "../../typechain-types";
import { vaultFixture } from "./fixture";

describe("Binary Option - Vault Manager Test", () => {
    describe("Create New Vault", () => {
        it("Should be reverted from not owner", async () => {
            const {vaultManager, notOperator, owner, uToken, config} = await loadFixture(vaultFixture);
            await expect(vaultManager.connect(notOperator).createNewVault("Balance BTC/USDC Vault", "BTCUSDC", 0, uToken.address, config.address)).to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("Should be able to create new vault from owner", async () => {
            const {vaultManager, notOperator, owner, uToken, config} = await loadFixture(vaultFixture);
            await vaultManager.connect(owner).createNewVault("Balance BTC/USDC Vault", "BTCUSDC", 0, uToken.address, config.address);
            const newVault = await vaultManager.vaults(uToken.address);
            expect(await vaultManager.underlyingTokens(0)).to.be.equal(uToken.address);
        });
    });

    describe("Stake", () => {
        it("Should be reverted with not existing vault", async () => {
            const {vaultManager, notOperator, owner, uToken, uToken_other, config} = await loadFixture(vaultFixture);
            await expect(vaultManager.connect(owner).stake(uToken_other.address, ethers.utils.parseEther("1"))).to.be.revertedWith("invalid uToken");
        });

        it("Should be reverted with zero amount", async () => {
            const {vaultManager, notOperator, owner, uToken, uToken_other, config} = await loadFixture(vaultFixture);
            await expect(vaultManager.connect(owner).stake(uToken.address, 0)).to.be.revertedWith("zero amount");
        });

        it("Should be able to deposit with underlying token", async () => {
            const {vaultManager, notOperator, owner, uToken, uToken_other, config} = await loadFixture(vaultFixture);
            const newVault = await vaultManager.vaults(uToken.address);
            const currentBalance = await uToken.balanceOf(newVault);

            uToken.connect(owner).approve(newVault, ethers.utils.parseEther("10"));
            await vaultManager.connect(owner).stake(uToken.address, ethers.utils.parseEther("1"));
            const balance = await uToken.balanceOf(newVault);
            expect(balance.sub(currentBalance)).to.be.equal(ethers.utils.parseEther("1"));
        });
    });

    describe("Unstake", () => {
        it("Should be reverted with not existing vault", async () => {
            const {vaultManager, notOperator, owner, uToken, uToken_other, config} = await loadFixture(vaultFixture);
            await expect(vaultManager.connect(owner).unstake(uToken_other.address, ethers.utils.parseEther("1"))).to.be.revertedWith("invalid uToken");
        });

        it("Should be reverted with zero amount", async () => {
            const {vaultManager, notOperator, owner, uToken, uToken_other, config} = await loadFixture(vaultFixture);
            await expect(vaultManager.connect(owner).unstake(uToken.address, 0)).to.be.revertedWith("zero amount");
        });

        it("Should be able to unstake with underlying token", async () => {
            const {vaultManager, notOperator, owner, uToken, uToken_other, config} = await loadFixture(vaultFixture);
            const newVault = await vaultManager.vaults(uToken.address);
            const vault = <BinaryVault>(new Contract(newVault, BinaryVault__factory.abi, owner));
            await vault.setVaultManager(vaultManager.address);

            const currentBalance = await uToken.balanceOf(owner.address);

            await vaultManager.connect(owner).unstake(uToken.address, ethers.utils.parseEther("1"));
            const balance = await uToken.balanceOf(owner.address);
            expect(balance.sub(currentBalance)).to.be.equal(ethers.utils.parseEther("1"));
        });
    });
});