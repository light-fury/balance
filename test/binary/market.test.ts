import { expect } from "chai"
import { loadFixture } from "ethereum-waffle"
import { ethers, network } from "hardhat"
import { evm_mine_blocks } from "../helper"
import { marketFixture } from "./fixture"

describe.only("Binary Option Trading - Market", () => {
    describe("Execute Round", async () => {
        it("Should reverted when not operator: ", async () => {
            const {market, operator, notOperator} = await loadFixture(marketFixture);
            const latestBlock = await ethers.provider.getBlock("latest");
            
            await expect(
                market.connect(notOperator).executeRound([0], 1000, latestBlock.timestamp)
            ).to.be.revertedWith("operator: wut?");
        });

        it("Should reverted when paused: ", async () => {
            const {market, operator} = await loadFixture(marketFixture);
            const latestBlock = await ethers.provider.getBlock("latest");
            await market.connect(operator).setPause(true);

            await expect(
                market.connect(operator).executeRound([0], 1000, latestBlock.timestamp)
            ).to.be.revertedWith("Pausable: paused");
            await market.connect(operator).setPause(false);
        });

        it("Should reverted if genesis start and lock: ", async () => {
            const {market, operator} = await loadFixture(marketFixture);
            const latestBlock = await ethers.provider.getBlock("latest");

            await expect(
                market.connect(operator).executeRound([0], 1000, latestBlock.timestamp)
            ).to.be.revertedWith("Can only run after genesisStartRound is triggered");
        });

        it("Should be able to execute Round with operator wallet after genesis start and lock: ", async () => {
            const {market, operator} = await loadFixture(marketFixture);
            // mine one block
            await network.provider.send("hardhat_mine", ["0x1"]); // min 1 blocks
            
            await market.connect(operator).genesisStartRound();
            expect((await market.rounds(0, 1)).epoch).to.be.equal(1);
            expect(await market.oracleLatestRoundId()).to.be.equal(0);
            expect(await market.currentEpochs(0)).to.be.equal(1);

            await network.provider.send("hardhat_mine", ["0xa"]); // min 10 blocks
            await market.connect(operator).genesisLockRound(0);
            expect(await market.oracleLatestRoundId()).to.be.equal(1);
            expect(await market.currentEpochs(0)).to.be.equal(2);

            await network.provider.send("hardhat_mine", ["0xa"]); // min 10 blocks
            const latestBlock = await ethers.provider.getBlock("latest");

            await market.connect(operator).executeRound([0], 1000, latestBlock.timestamp);
            expect(await market.currentEpochs(0)).to.be.equal(3);
            expect(await market.oracleLatestRoundId()).to.be.equal(2);
        });
    });

    describe("Bet", async () => {
        it("Should not be able to place bet when paused", async () => {
            const {market, operator, notOperator} = await loadFixture(marketFixture);
            await market.connect(operator).setPause(true);
            await expect(
                market.connect(notOperator).openPosition(ethers.utils.parseEther("0.1"), 0, "0")
            ).to.be.revertedWith("Pausable: paused");
            await market.connect(operator).setPause(false);
        });

        it("Should not be able to place bet with too small bet amount", async () => {
            const {market, owner, uToken, notOperator} = await loadFixture(marketFixture);
            await uToken.connect(owner).transfer(notOperator.address, ethers.utils.parseEther("1"));
            await uToken.connect(notOperator).approve(market.address, ethers.utils.parseEther("100"));
            
            await expect(
                market.connect(notOperator).openPosition(ethers.utils.parseEther("0.01"), 0, "0")
            ).to.be.revertedWith("Bet amount must be greater than minBetAmount");
        });
    })
})