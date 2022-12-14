import { ethers } from "hardhat";

async function claim() {
  try {
    let [deployer, other] = await ethers.getSigners();
    const market = await ethers.getContractAt(
      "BinaryMarket",
      "0x28ffc335a6e7a02eafe63d8052ac8c695ea4b987",
      deployer
    );
    for (let i = 0; i < 3; i++) {
      const currentEpoch = await market.currentEpochs(i);
      if (await market.isClaimable(i, currentEpoch.sub(2), other.address)) {
        await market.connect(other).claim(i, currentEpoch.sub(2));
        console.log("claimed: ", i, currentEpoch.sub(2).toNumber());
      } else {
        console.log("Not claimable");
      }
    }
  } catch (e) {
    console.log("openPosition: ", e);
  }
}
function run() {
  claim();
  setInterval(() => {
    claim();
  }, 60000);
}

run();
