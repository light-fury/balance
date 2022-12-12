import { ethers } from "hardhat";

async function main() {
    let [deployer] = await ethers.getSigners();
    console.log("Executing contract method with the account: " + deployer.address);
  
    // Goerli market contract.
    const market = await ethers.getContractAt("BinaryMarket", "0xD7c801f2c9085290D4AAF927Bb3f76FC3a0C333B", deployer);
    const uToken = await ethers.getContractAt("MockERC20", "0x5Ad048cf68111b81780b0284582C99Cd581ede9e", deployer);
    const vaultAddress = await market.vault();
    const vault = await ethers.getContractAt("BinaryVault", vaultAddress);
    console.log("vault: ", await vault.whitelistedMarkets(market.address), await uToken.balanceOf(vault.address));
    // await vault.whitelistMarket(market.address, true);
    // await uToken.approve(market.address, ethers.utils.parseEther("100"));
    // await uToken.transfer(vault, ethers.utils.parseEther("100"));
    // const oracleAddress = await market.oracle();
    // const oracle = await ethers.getContractAt("Oracle", oracleAddress);
    // await oracle.setWriter(market.address, true);

    
    
    // await market.setPause(true);
    // await market.setPause(false);
    
    
    // await market.genesisStartRound();
    // await market.genesisLockRound(0);

    const latestRoundID = await market.oracleLatestRoundId();
    console.log("latestROundId: ", latestRoundID);

    // await market.setTimeframes( [{
    //     id: 0,
    //     interval: 60,
    //     intervalBlocks: 4,
    //     bufferBlocks: 3,
    // }, {
    //     id: 1,
    //     interval: 300,
    //     intervalBlocks: 20,
    //     bufferBlocks: 5,
    // }, {
    //     id: 2,
    //     interval: 900,
    //     intervalBlocks: 60,
    //     bufferBlocks: 8,
    // }])

    // await market.executeRound([0], 1004);
    const currentEpoch = await market.currentEpochs(0);
    const isClaimable = await market.isClaimable(0, currentEpoch.sub(2), deployer.address);
    console.log("currentEpoch: ", currentEpoch.toString(), isClaimable);
    const currentRound = await market.rounds(0, currentEpoch.sub(2));
    console.log("leger: ", currentRound, await market.ledger(0, currentEpoch.sub(2), deployer.address))
    await market.claim(0, currentEpoch.sub(2));


    // await market.openPosition(ethers.utils.parseEther("0.01"), 0, 0);
    
}

main();