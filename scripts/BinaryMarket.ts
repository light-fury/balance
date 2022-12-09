import { ethers } from "hardhat";

async function main() {
    let [deployer] = await ethers.getSigners();
    console.log("Executing contract method with the account: " + deployer.address);
  
    // Goerli market contract.
    const market = await ethers.getContractAt("BinaryMarket", "0xa506281be28d95ebb263ce547d12d3f1d8ac2126", deployer);
    await market.setPause(false);
}

main();