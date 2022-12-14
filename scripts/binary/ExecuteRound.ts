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
    const executableTimeframes = await market.getExecutableTimeframes();
    const timeframes = executableTimeframes.replace(",", "").split("");
    console.log("timeframes: ", timeframes, executableTimeframes);
    if (timeframes.filter(item => ((item !== '') && (item !== ","))).length > 0) {
      const ids = timeframes.map(item => Number(item));
      console.log("ids: ", ids);
        await market.executeRound(ids, Math.round(price));
        console.log("Executed: ", ids, price);
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