import { ethers } from "hardhat";

async function main() {
    let [deployer] = await ethers.getSigners();
    console.log("Executing contract method with the account: " + deployer.address);
  
    // Goerli market contract.
    const market = await ethers.getContractAt("BinaryMarket", "0xe9a17b850decbead2660106aaed95e7764a0e4b3", deployer);
    await market.setVault("0x42152e05c9a2ff8b0b452227bbb83849856ff80e");
}

main();