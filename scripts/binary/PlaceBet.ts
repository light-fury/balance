import { BigNumber } from "ethers";
import { ethers } from "hardhat";
async function bet() {
  try {
    let [deployer, other] = await ethers.getSigners();
    const market = await ethers.getContractAt(
      "BinaryMarket",
      "0x28ffc335a6e7a02eafe63d8052ac8c695ea4b987",
      deployer
    );
    // const uToken = await ethers.getContractAt("MockERC20", "0x5Ad048cf68111b81780b0284582C99Cd581ede9e", deployer);
    // await uToken.connect(other).approve(market.address, ethers.utils.parseEther("10000000"));
    const position = Math.random() > 0.5 ? 0 : 1;
    const amount = (Math.random() * 10).toFixed(2);
    const timeframeId = Math.floor(Math.random() * 1000) % 3;
    await market
      .connect(other)
      .openPosition(ethers.utils.parseEther(amount), timeframeId, position);
    console.log("placed bet: ", timeframeId);
  } catch (e) {
    console.log("openPosition: ", e);
  }
}
function run() {
  bet();

  setInterval(() => {
    bet();
  }, 70000);
}

run()
