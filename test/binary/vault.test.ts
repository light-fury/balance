import { expect } from "chai";
import { loadFixture } from "ethereum-waffle";
import { Contract, ethers } from "ethers";
import { BinaryVault, BinaryVault__factory } from "../../typechain-types";
import { vaultFixture, marketFixture } from "./fixture";

describe("Binary Option - Vault & Vault Manager Test", () => {
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

    describe("Whitelist market", () => {
        it("Should be reverted from non owner", async () => {
            const {vaultManager, notOperator, uToken, owner} = await loadFixture(vaultFixture);
            const {market} = await loadFixture(marketFixture);
            const vaultAddress = await vaultManager.vaults(uToken.address);
            const vault = BinaryVault__factory.connect(vaultAddress, owner);
            await expect(vault.connect(notOperator).whitelistMarket(market.address, true)).to.be.revertedWith("admin: wut?");
        });

        it("Should be able to whitelist market from owner", async () => {
            const {vaultManager, notOperator, uToken, owner} = await loadFixture(vaultFixture);
            const {market} = await loadFixture(marketFixture);
            const vaultAddress = await vaultManager.vaults(uToken.address);
            const vault = BinaryVault__factory.connect(vaultAddress, owner);
            expect(await vault.whitelistMarket(market.address, true))
                .to
                .emit(vault, "WhitelistMarketChanged")
                .withArgs(market.address, true);
            
            expect(await vault.whitelistedMarkets(market.address)).to.be.equal(true);

        });
    });

    describe("Add New Liquidity", () => {
        it("Should be reverted with zero address user or zero amount", async () => {
            const {vaultManager, notOperator, owner, uToken, uToken_other, config} = await loadFixture(vaultFixture);
            const vaultAddress = await vaultManager.vaults(uToken.address);
            const vault = BinaryVault__factory.connect(vaultAddress, owner);

            await expect(vault.addNewLiquidityPosition("0x0000000000000000000000000000000000000000", ethers.utils.parseEther("1"))).to.be.revertedWith("ZERO_ADDRESS()");
            await expect(vault.addNewLiquidityPosition(owner.address, ethers.utils.parseEther("0"))).to.be.revertedWith("ZERO_AMOUNT()");
        });

        it("Should be reverted with less than 10^3 amount token", async () => {
            const {vaultManager, notOperator, owner, uToken, uToken_other, config} = await loadFixture(vaultFixture);
            const vaultAddress = await vaultManager.vaults(uToken.address);
            const vault = BinaryVault__factory.connect(vaultAddress, owner);

            await uToken.connect(owner).approve(vault.address, ethers.utils.parseEther("1"));
            await expect(vault.addNewLiquidityPosition(owner.address, ethers.utils.parseUnits("1", 2))).to.be.revertedWith("Insufficient amount");
        });

        it("Should be able to add liquidity with enough amount", async () => {
            const {vaultManager, notOperator, owner, uToken, uToken_other, config} = await loadFixture(vaultFixture);
            const vaultAddress = await vaultManager.vaults(uToken.address);
            const vault = BinaryVault__factory.connect(vaultAddress, owner);

            expect(await vault.addNewLiquidityPosition(owner.address, ethers.utils.parseEther("1"))).to
                .emit(vault, "NewLiquidityAdded")
                .withArgs(owner.address, 0, ethers.utils.parseEther("1"), ethers.utils.parseEther("1"));

            expect(await vault.totalShareSupply()).to.be.equal(ethers.utils.parseEther("1"));
            expect(await vault.shareBalances(0)).to.be.equal(ethers.utils.parseEther("1"));
            expect(await vault.ownerOf(0)).to.be.equal(owner.address);
            expect((await vault.getSharesOfUser(owner.address)).shares).to.be.equal(ethers.utils.parseEther("1"));
            expect((await vault.getSharesOfUser(owner.address)).underlyingTokenAmount).to.be.equal(ethers.utils.parseEther("1"));
        });
    });

    describe("Add liquidity to existing position", () => {
        it("Should be reverted with non exist token id", async () => {
            const {vaultManager, notOperator, owner, uToken, uToken_other, config} = await loadFixture(vaultFixture);
            const vaultAddress = await vaultManager.vaults(uToken.address);
            const vault = BinaryVault__factory.connect(vaultAddress, owner);

            await expect(vault.addLiquidityPosition(owner.address, ethers.utils.parseEther("1"), 1)).to.be.revertedWith("Non exists token");
        });

        it("Should be reverted from non owner or not approved user", async () => {
            const {vaultManager, notOperator, owner, uToken, uToken_other, config} = await loadFixture(vaultFixture);
            const vaultAddress = await vaultManager.vaults(uToken.address);
            const vault = BinaryVault__factory.connect(vaultAddress, owner);

            await expect(vault.addLiquidityPosition(notOperator.address, ethers.utils.parseEther("1"), 0)).to.be.revertedWith("Not owner");
            await expect(vault.connect(notOperator).addLiquidityPosition(owner.address, ethers.utils.parseEther("1"), 0)).to.be.revertedWith("Not approved or owner");
        });

        it("Should be able to add liquidity from token owner",async () => {
            const {vaultManager, notOperator, owner, uToken, uToken_other, config} = await loadFixture(vaultFixture);
            const vaultAddress = await vaultManager.vaults(uToken.address);
            const vault = BinaryVault__factory.connect(vaultAddress, owner);

            await uToken.connect(owner).approve(vault.address, ethers.utils.parseEther("100"));
            
            expect(await vault.addLiquidityPosition(owner.address, ethers.utils.parseEther("1"), 0)).to
                .emit(vault, "LiquidityAdded")
                .withArgs(owner.address, 0, 1, ethers.utils.parseEther("1"), ethers.utils.parseEther("1"));
            
            expect(await vault.totalShareSupply()).to.be.equal(ethers.utils.parseEther("2"));
            expect(await vault.shareBalances(0)).to.be.equal(ethers.utils.parseEther("0"));
            expect(await vault.shareBalances(1)).to.be.equal(ethers.utils.parseEther("2"));
            expect(await vault.ownerOf(1)).to.be.equal(owner.address);
            expect((await vault.getSharesOfUser(owner.address)).shares).to.be.equal(ethers.utils.parseEther("2"));
            expect((await vault.getSharesOfUser(owner.address)).underlyingTokenAmount).to.be.equal(ethers.utils.parseEther("2"));
            // NFT total supply should be 1
            expect(await vault.totalSupply()).to.be.equal(1);
        });

        it("Add new liquidity from other user",async () => {
            const {vaultManager, notOperator, owner, uToken, uToken_other, config} = await loadFixture(vaultFixture);
            const vaultAddress = await vaultManager.vaults(uToken.address);
            const vault = BinaryVault__factory.connect(vaultAddress, owner);
            
            await uToken.connect(owner).transfer(notOperator.address, ethers.utils.parseEther("10"));
            await uToken.connect(notOperator).approve(vault.address, ethers.utils.parseEther("100"));
            
            expect(await vault.connect(notOperator).addNewLiquidityPosition(notOperator.address, ethers.utils.parseEther("1"))).to
                .emit(vault, "NewLiquidityAdded")
                .withArgs(notOperator.address, 2, ethers.utils.parseEther("1"), ethers.utils.parseEther("1"));

                expect(await vault.totalShareSupply()).to.be.equal(ethers.utils.parseEther("3"));
                expect(await vault.shareBalances(0)).to.be.equal(ethers.utils.parseEther("0"));
                expect(await vault.shareBalances(1)).to.be.equal(ethers.utils.parseEther("2"));
                expect(await vault.shareBalances(2)).to.be.equal(ethers.utils.parseEther("1"));
                expect(await vault.ownerOf(1)).to.be.equal(owner.address);
                expect(await vault.ownerOf(2)).to.be.equal(notOperator.address);
                expect((await vault.getSharesOfUser(owner.address)).shares).to.be.equal(ethers.utils.parseEther("2"));
                expect((await vault.getSharesOfUser(owner.address)).underlyingTokenAmount).to.be.equal(ethers.utils.parseEther("2"));
                expect((await vault.getSharesOfUser(notOperator.address)).shares).to.be.equal(ethers.utils.parseEther("1"));
                expect((await vault.getSharesOfUser(notOperator.address)).underlyingTokenAmount).to.be.equal(ethers.utils.parseEther("1"));
                // NFT total supply should be 1
                expect(await vault.totalSupply()).to.be.equal(2);
        });
    });

    describe("Remove liquidity from certain position", () => {
        it("Should be reverted with zero amount",async () => {
            const {vaultManager, notOperator, owner, uToken, uToken_other, config} = await loadFixture(vaultFixture);
            const vaultAddress = await vaultManager.vaults(uToken.address);
            const vault = BinaryVault__factory.connect(vaultAddress, owner);
            await expect(vault.removeLiquidityPosition(owner.address, 1, ethers.utils.parseEther("0"))).to.be.revertedWith("ZERO_AMOUNT()");
        });

        it("Should be reverted with non exists token id",async () => {
            const {vaultManager, notOperator, owner, uToken, uToken_other, config} = await loadFixture(vaultFixture);
            const vaultAddress = await vaultManager.vaults(uToken.address);
            const vault = BinaryVault__factory.connect(vaultAddress, owner);
            await expect(vault.removeLiquidityPosition(owner.address, 3, ethers.utils.parseEther("1"))).to.be.revertedWith("Invalid token id");
        });

        it("Should be reverted from not token owner",async () => {
            const {vaultManager, notOperator, owner, uToken, uToken_other, config} = await loadFixture(vaultFixture);
            const vaultAddress = await vaultManager.vaults(uToken.address);
            const vault = BinaryVault__factory.connect(vaultAddress, owner);
            await expect(vault.removeLiquidityPosition(owner.address, 2, ethers.utils.parseEther("1"))).to.be.revertedWith("Not owner");
        });

        it("Should be reverted with too much remove amount",async () => {
            const {vaultManager, notOperator, owner, uToken, uToken_other, config} = await loadFixture(vaultFixture);
            const vaultAddress = await vaultManager.vaults(uToken.address);
            const vault = BinaryVault__factory.connect(vaultAddress, owner);
            await expect(vault.connect(notOperator).removeLiquidityPosition(notOperator.address, 2, ethers.utils.parseEther("2"))).to.be.revertedWith("Insufficient shares");
        });

        it("Should be able to remove from token owner",async () => {
            const {vaultManager, notOperator, owner, uToken, uToken_other, config} = await loadFixture(vaultFixture);
            const vaultAddress = await vaultManager.vaults(uToken.address);
            const vault = BinaryVault__factory.connect(vaultAddress, owner);
            const nextTokenId = await vault.nextTokenId();

            const prevBalance = await uToken.balanceOf(owner.address);
            const prevVaultTokenBalance = await uToken.balanceOf(vault.address);
            const prevTotalSupply = await vault.totalSupply()
            const prevTotalShareSupply = await vault.totalShareSupply();

            expect(await vault.connect(owner).removeLiquidityPosition(owner.address, 1, ethers.utils.parseEther("1"))).to
                .emit(vault, "LiquidityRemovedFromPosition")
                .withArgs(owner.address, 1, ethers.utils.parseEther("1"), ethers.utils.parseEther("1"), nextTokenId, ethers.utils.parseEther("1"));
            
            expect(await uToken.balanceOf(owner.address)).to.be.equal(prevBalance.add(ethers.utils.parseEther("1")));
            expect(await uToken.balanceOf(vault.address)).to.be.equal(prevVaultTokenBalance.sub(ethers.utils.parseEther("1")));
            expect(await vault.shareBalances(nextTokenId)).to.be.equal(ethers.utils.parseEther("1"));
            expect(await vault.shareBalances(1)).to.be.equal(ethers.utils.parseEther("0"));
            expect(await vault.totalShareSupply()).to.be.equal(prevTotalShareSupply.sub(ethers.utils.parseEther("1")));
            expect(await vault.totalSupply()).to.be.equal(prevTotalSupply);
        });

        it("Should be burnt if remove all shares",async () => {
            const {vaultManager, notOperator, owner, uToken, uToken_other, config} = await loadFixture(vaultFixture);
            const vaultAddress = await vaultManager.vaults(uToken.address);
            const vault = BinaryVault__factory.connect(vaultAddress, owner);
            const tokenIds = await vault.tokensOfOwner(owner.address);
            const shareAmount = await vault.shareBalances(tokenIds[0]);

            const prevTotalSupply = await vault.totalSupply();
            await vault.removeLiquidityPosition(owner.address, tokenIds[0], shareAmount);

            expect(await vault.totalSupply()).to.be.equal(prevTotalSupply.sub(1));
        });
    });

    describe("Remove liquidity", () => {
        it("Should be reverted with zero amount",async () => {
            const {vaultManager, notOperator, owner, uToken, uToken_other, config} = await loadFixture(vaultFixture);
            const vaultAddress = await vaultManager.vaults(uToken.address);
            const vault = BinaryVault__factory.connect(vaultAddress, owner);
            await expect(vault.removeLiquidity(owner.address, ethers.utils.parseEther("0"))).to.be.revertedWith("ZERO_AMOUNT()");
        });

        it("Should be reverted from not token owner",async () => {
            const {vaultManager, notOperator, owner, uToken, uToken_other, config} = await loadFixture(vaultFixture);
            const vaultAddress = await vaultManager.vaults(uToken.address);
            const vault = BinaryVault__factory.connect(vaultAddress, owner);
            await expect(vault.removeLiquidity(notOperator.address, ethers.utils.parseEther("1"))).to.be.revertedWith("Not approved");
        });

        it("Should be reverted with too much remove amount",async () => {
            const {vaultManager, notOperator, owner, uToken, uToken_other, config} = await loadFixture(vaultFixture);
            const vaultAddress = await vaultManager.vaults(uToken.address);
            const vault = BinaryVault__factory.connect(vaultAddress, owner);
            await expect(vault.connect(notOperator).removeLiquidity(notOperator.address, ethers.utils.parseEther("10"))).to.be.revertedWith("Insufficient share amount");
        });

        it("Should be able to remove liquidity with sufficient funds", async () => {
            const {vaultManager, notOperator, owner, uToken, uToken_other, config} = await loadFixture(vaultFixture);
            const vaultAddress = await vaultManager.vaults(uToken.address);
            const vault = BinaryVault__factory.connect(vaultAddress, owner);
            await vault.addNewLiquidityPosition(owner.address, ethers.utils.parseEther("5"));
            let tokenIds = await vault.tokensOfOwner(owner.address);

            await vault.addNewLiquidityPosition(owner.address, ethers.utils.parseEther("5"));
            tokenIds = await vault.tokensOfOwner(owner.address);

            const totalShareSupply = await vault.totalShareSupply();
            const totalSupply = await vault.totalSupply();

            let shares = await vault.getSharesOfUser(owner.address);
            const nextTokenId = await vault.nextTokenId();
            
            const prevVaultBalance = await uToken.balanceOf(vault.address);
            expect(await vault.removeLiquidity(owner.address, ethers.utils.parseEther("7"))).to
                .emit(vault, "LiquidityRemoved")
                .withArgs(owner.address, tokenIds, ethers.utils.parseEther("7"), ethers.utils.parseEther("7"), nextTokenId, ethers.utils.parseEther("3"));

            expect(await vault.totalShareSupply()).to.be.equal(totalShareSupply.sub(ethers.utils.parseEther("7")));
            expect(await vault.totalSupply()).to.be.equal(totalSupply.sub(tokenIds.length).add(1));
            expect((await vault.getSharesOfUser(owner.address)).shares).to.be.equal(shares.shares.sub(ethers.utils.parseEther("7")));
            expect((await vault.getSharesOfUser(owner.address)).underlyingTokenAmount).to.be.equal(shares.underlyingTokenAmount.sub(ethers.utils.parseEther("7")));
            expect(await uToken.balanceOf(vault.address)).to.be.equal(prevVaultBalance.sub(ethers.utils.parseEther("7")));
            expect((await vault.tokensOfOwner(owner.address))[0]).to.be.equal(nextTokenId);
        });
    });

    describe("Merge positions", () => {
        it("Should be reverted from not owner, or not approved",async () => {
            const {vaultManager, notOperator, owner, uToken, uToken_other, config} = await loadFixture(vaultFixture);
            const vaultAddress = await vaultManager.vaults(uToken.address);
            const vault = BinaryVault__factory.connect(vaultAddress, owner);

            await expect(vault.connect(notOperator).mergePositions(owner.address, [6])).to.be.revertedWith("Non owner or approved");
        });

        it("Should be able to merge",async () => {
            const {vaultManager, notOperator, owner, uToken, uToken_other, config} = await loadFixture(vaultFixture);
            const vaultAddress = await vaultManager.vaults(uToken.address);
            const vault = BinaryVault__factory.connect(vaultAddress, owner);

            await vault.addNewLiquidityPosition(owner.address, ethers.utils.parseEther("3"));
            const tokenIds = await vault.tokensOfOwner(owner.address);
            const nextTokenId = await vault.nextTokenId();
            const shares = (await vault.getSharesOfUser(owner.address)).shares;

            expect(await vault.mergePositions(owner.address, tokenIds)).to
                .emit(vault, "PositionMerged")
                .withArgs(owner.address, tokenIds, nextTokenId);

            expect((await vault.getSharesOfUser(owner.address)).shares).to.be.equal(shares);
        });
    });
});