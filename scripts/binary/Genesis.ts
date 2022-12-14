import { ethers } from "hardhat";

async function main() {
  let [deployer, other] = await ethers.getSigners();
  console.log(
    "Executing contract method with the account: " + deployer.address
  );

  // Goerli market contract.
  const market = await ethers.getContractAt(
    "BinaryMarket",
    "0x28ffc335a6e7a02eafe63d8052ac8c695ea4b987",
    deployer
  );

//   const uToken = await ethers.getContractAt("MockERC20", "0x5Ad048cf68111b81780b0284582C99Cd581ede9e", deployer);
//   const vaultAddress = await market.vault();
//   const vault = await ethers.getContractAt("BinaryVault", vaultAddress);
//   console.log("vault: ", await vault.whitelistedMarkets(market.address), await uToken.balanceOf(vault.address));
//   await vault.whitelistMarket(market.address, true);
//   await uToken.approve(market.address, ethers.utils.parseEther("100"));
//   await uToken.transfer(vault.address, ethers.utils.parseEther("100"));
//   const oracleAddress = await market.oracle();
//   const oracle = await ethers.getContractAt("Oracle", oracleAddress);
//   await oracle.setWriter(market.address, true);

// //   await market.setPause(true);
// //   await market.setPause(false);

//   await market.genesisStartRound();
  // setTimeout(() => {
  //     market.genesisLockRound(1);
  // }, 1000)

  setTimeout(() => {
    market.genesisLockRound(2)
  }, 10000);
}

main();
