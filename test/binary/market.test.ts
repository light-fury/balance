import { expect } from "chai"
import { loadFixture } from "ethereum-waffle"
import { ethers, network } from "hardhat"
import { marketFixture } from "./fixture"

describe("Binary Option Trading - Market & Market manager", () => {
    describe("Execute Round", async () => {
        it("Should reverted when not operator: ", async () => {
            const {market, operator, notOperator} = await loadFixture(marketFixture);
            const latestBlock = await ethers.provider.getBlock("latest");
            
            await expect(
                market.connect(notOperator).executeRound([0], 1000)
            ).to.be.revertedWith("operator: wut?");
        });

        it("Should reverted when paused: ", async () => {
            const {market, operator} = await loadFixture(marketFixture);
            const latestBlock = await ethers.provider.getBlock("latest");
            await market.connect(operator).setPause(true);

            await expect(
                market.connect(operator).executeRound([0], 1000)
            ).to.be.revertedWith("Pausable: paused");
            await market.connect(operator).setPause(false);
        });

        it("Should reverted if genesis start and lock: ", async () => {
            const {market, operator} = await loadFixture(marketFixture);
            const latestBlock = await ethers.provider.getBlock("latest");

            await expect(
                market.connect(operator).executeRound([0], 1000)
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

            await market.connect(operator).executeRound([0], 1000);
            expect(await market.currentEpochs(0)).to.be.equal(3);
            expect(await market.oracleLatestRoundId()).to.be.equal(2);
        });
    });

    describe("Bet", async () => {
        // it("Should not be able to place bet when paused", async () => {
        //     const {market, operator, notOperator} = await loadFixture(marketFixture);
        //     await market.connect(operator).setPause(true);
            
        //     expect(await market.getExecutableTimeframes()).to.be.equal("");

        //     await expect(
        //         market.connect(notOperator).openPosition(ethers.utils.parseEther("0.1"), 0, "0")
        //     ).to.be.revertedWith("Pausable: paused");
        //     await market.connect(operator).setPause(false);
        // });

        it("Should not be able to place bet with too small bet amount", async () => {
            const {market, owner, uToken, notOperator} = await loadFixture(marketFixture);
            await uToken.connect(owner).transfer(notOperator.address, ethers.utils.parseEther("1"));
            await uToken.connect(notOperator).approve(market.address, ethers.utils.parseEther("100"));
            
            await expect(
                market.connect(notOperator).openPosition(ethers.utils.parseEther("0.01"), 0, "0")
            ).to.be.revertedWith("Bet amount must be greater than minBetAmount");
        });

        it("Should be able to place bet with enough bet amount", async () => {
            const {market, owner, uToken, notOperator} = await loadFixture(marketFixture);
            await uToken.connect(owner).transfer(notOperator.address, ethers.utils.parseEther("1"));
            await uToken.connect(notOperator).approve(market.address, ethers.utils.parseEther("100"));
            const currentEpoch = await market.currentEpochs(0);
            await market.connect(notOperator).openPosition(ethers.utils.parseEther("1"), 0, 0);
            
            expect(await market.userRounds(0, notOperator.address, 0)).to.be.equal(currentEpoch);
            const betAmount = (await market.ledger(0, currentEpoch.toNumber(), notOperator.address)).amount;
            expect(betAmount).to.be.equal(ethers.utils.parseEther("1"));
        });

        it("Should be able to lock current round", async () => {
            const {market, owner, uToken, operator} = await loadFixture(marketFixture);
            const latestBlock = await ethers.provider.getBlock("latest");
            await network.provider.send("hardhat_mine", ["0xa"]); // min 10 blocks
            
            const executableTimeframes = await market.getExecutableTimeframes();
            console.log("executableTimeframes: ", executableTimeframes);
            expect(executableTimeframes.split(",")[0]).to.be.equal('0');

            await market.connect(operator).executeRound([0], 1005);
            const currentEpoch = await market.currentEpochs(0);
            const round = await market.rounds(0, currentEpoch.toNumber() - 1);
            expect((await market.rounds(0, currentEpoch.toNumber() - 1)).lockPrice).to.be.equal(1005);
        });

        it("Should be able to close current round", async () => {
            const {market, owner, uToken, operator} = await loadFixture(marketFixture);
            const latestBlock = await ethers.provider.getBlock("latest");

            // move block
            await network.provider.send("hardhat_mine", ["0xa"]); // min 10 blocks

            await market.connect(operator).executeRound([0], 1008);
            const currentEpoch = await market.currentEpochs(0);
            const round = await market.rounds(0, currentEpoch.toNumber() - 1);
            expect((await market.rounds(0, currentEpoch.toNumber() - 2)).closePrice).to.be.equal(1008);
        });

        it("Should not be able to close current round within progress", async () => {
            const {market, owner, uToken, operator} = await loadFixture(marketFixture);
            const latestBlock = await ethers.provider.getBlock("latest");

            await expect(market.connect(operator).executeRound([0], 1008)).to.be.revertedWith("Can only lock round after lockBlock");
        });
    });

    describe("Claim", () => {
        it("Claimable", async () => {
            const {market, notOperator, uToken, operator} = await loadFixture(marketFixture);
            const epoch = await market.connect(notOperator).userRounds(0, notOperator.address, 0);
            const betInfo = await market.ledger(0, epoch, notOperator.address);
            expect(await market.connect(notOperator).isClaimable(0, epoch, notOperator.address)).to.be.equal(true);
        });

        it("Claim", async () => {
            const {market, notOperator, uToken, operator} = await loadFixture(marketFixture);
            const epoch = await market.connect(notOperator).userRounds(0, notOperator.address, 0);
            const prevBalance = await uToken.balanceOf(notOperator.address);
            await market.connect(notOperator).claim(0, epoch);
            const afterBalance = await uToken.balanceOf(notOperator.address);
            expect(afterBalance.sub(prevBalance)).to.be.equal(ethers.utils.parseEther("1").mul(2).mul(9).div(10))
        });

        it("Prevent duplicate claim", async () => {
            const {market, notOperator, uToken, operator} = await loadFixture(marketFixture);
            const epoch = await market.connect(notOperator).userRounds(0, notOperator.address, 0);
            await expect(market.connect(notOperator).claim(0, epoch)).to.be.revertedWith('Rewards claimed');
        });
        
        it("Should not be claimable before round ends", async () => {
            const {market, notOperator, uToken, operator} = await loadFixture(marketFixture);
            const epoch = await market.connect(notOperator).userRounds(0, notOperator.address, 0);
            await expect(market.connect(notOperator).claim(0, epoch.add(1))).to.be.revertedWith('Round has not ended');
        });

        it("Should not be claimable before round ends", async () => {
            const {market, notOperator, uToken, operator} = await loadFixture(marketFixture);
            const epoch = await market.connect(notOperator).userRounds(0, notOperator.address, 0);
            await expect(market.connect(notOperator).claim(0, epoch.add(2))).to.be.revertedWith('Round has not ended');
        });

        it("Should not be claimable before round starts", async () => {
            const {market, notOperator, uToken, operator} = await loadFixture(marketFixture);
            const epoch = await market.connect(notOperator).userRounds(0, notOperator.address, 0);
            await expect(market.connect(notOperator).claim(0, epoch.add(3))).to.be.revertedWith('Round has not started');
        });
        
    });

    describe("Execute Round - (2)", () => {
        it("Should be able to execute after long time", async () => {
            const {market, notOperator, uToken, operator} = await loadFixture(marketFixture);
            await network.provider.send("hardhat_mine", ["0xa"]); // min 10 blocks
            const currentEpoch = await market.currentEpochs(0);
            await market.connect(operator).executeRound([0], 1010);
            expect(await market.currentEpochs(0)).to.be.equal(currentEpoch.add(1));

            await network.provider.send("hardhat_mine", ["0x3e8"]); // min 1000 blocks
            await market.connect(operator).executeRound([0], 1010);
            expect(await market.currentEpochs(0)).to.be.equal(currentEpoch.add(2));
        })
    });

    describe("Place Bet - (2)", () => {
        it("Should be able to bet after long time", async () => {
            const {market, notOperator, uToken, operator} = await loadFixture(marketFixture);
            await network.provider.send("hardhat_mine", ["0x3e8"]); // min 1000 blocks
            // not necessary to call execute round
            expect(await market.connect(notOperator).isNecessaryToExecute(0)).to.be.equal(false);
            await market.connect(notOperator).openPosition(ethers.utils.parseEther("0.1"), 0, 0); // bet to bull
            expect(await market.isNecessaryToExecute(0)).to.be.equal(true);

            const currentEpoch = await market.currentEpochs(0);
            await market.connect(operator).executeRound([0], 1020);

            // no need since not reached to lock block or end block
            expect(await market.isNecessaryToExecute(0)).to.be.equal(false);

            await network.provider.send("hardhat_mine", ["0x10"]); // min 16 blocks

            expect((await market.rounds(0, currentEpoch)).lockPrice).to.be.equal(1020);
            expect((await market.rounds(0, currentEpoch)).oracleCalled).to.be.equal(false);

            expect((await market.rounds(0, currentEpoch.sub(1))).closePrice).to.be.equal(1020);
            expect((await market.rounds(0, currentEpoch.sub(1))).lockPrice).to.be.equal(1010);
            expect((await market.rounds(0, currentEpoch.sub(1))).oracleCalled).to.be.equal(true);
            expect(await market.isNecessaryToExecute(0)).to.be.equal(true);

        });

        it("No need to execute round if both current round and prev round has no bet", async () => {
            const {market, notOperator, uToken, operator} = await loadFixture(marketFixture);
            await network.provider.send("hardhat_mine", ["0x100"]); // min 160 blocks

            // still necessary since prev round (active) has not been ended
            expect(await market.isNecessaryToExecute(0)).to.be.equal(true);

            await market.connect(operator).executeRound([0], 1000);

            // not necessary
            expect(await market.isNecessaryToExecute(0)).to.be.equal(false);
            await network.provider.send("hardhat_mine", ["0x100"]); // min 160 blocks
            expect(await market.isNecessaryToExecute(0)).to.be.equal(false);

        });
    });
})