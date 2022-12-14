import { ethers } from "hardhat";
let round = 0;
let counter = 0;

async function executeRound() {
  try {
    const price = Math.random() * 2000;
    let [deployer] = await ethers.getSigners();
    const market = await ethers.getContractAt(
      "BinaryMarket",
      "0x28ffc335a6e7a02eafe63d8052ac8c695ea4b987",
      deployer
    );
    const {result, count} = await market.getExecutableTimeframes();
    if (count.toNumber() > 0) {
      await market.executeRound(result.slice(0, count.toNumber()), Math.round(price));
      console.log("Executed: ", result.slice(0, count.toNumber()), price);
    } else {
        console.log("Not executable");
    }
  } catch (e) {
    console.log("executeRound: ", e);
  }
}

function runTimer() {
  executeRound();
  setInterval(() => {
    executeRound();
  }, 60000); // 1m
}

runTimer();