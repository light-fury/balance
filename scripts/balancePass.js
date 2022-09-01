const { ethers } = require("hardhat");

async function main() {
  let [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account: " + deployer.address);

  // const network = "rinkeby";
  const network = "mainnet";

  const maxMint = 350;
  const baseTokenURI = "ipfs://Qmc8A19qUxy1VWeSDtJj9cGk1DAfE88E47Xb5BFn5Z6Hg1";
  const passNFT = await ethers.getContractFactory("BalancePass");
  //const passnft = await passNFT.attach("0xa3DDAf083e491ecd5CbdCbd7DcC504cA7c0f2408"); // rinkeby
  //const passnft = await passNFT.attach("0x2fd0ff45263143dcd616ecada45c0d22e49adbb7"); // mainnet
  const passnft = await passNFT.deploy(maxMint, baseTokenURI, true);
  console.log(`Deployed liqdnft to: ${passnft.address}`);

  console.log(
    `\nVerify:\nnpx hardhat verify --network ${network} ` +
      `${passnft.address} "${maxMint}" "${baseTokenURI}"`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
