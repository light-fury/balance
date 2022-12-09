import { ethers } from "hardhat";

async function main() {
    let [deployer] = await ethers.getSigners();
    console.log("Executing contract method with the account: " + deployer.address);
  
    // Goerli market contract.
    const market = await ethers.getContractAt("BinaryMarket", "0xc6272904044ab8b8d970285bc8ffacd4c94bf00b", deployer);
    await market.setName("Binary BTC/USDT Market");
}

main();