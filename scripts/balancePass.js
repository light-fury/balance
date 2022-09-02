const { ethers } = require("hardhat");

async function main() {
  let [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account: " + deployer.address);

  const network = "rinkeby";
  // const network = "mainnet";

  const maxMint = 350;
  const maxMintWalletLimit = 1;

  // FIXME prod values are WL1 = Mon 9/5 18:00 UTC, WL2 = WL1 + 1hour, public = WL2 + 1hour
  const whitelist1MintStartTimestamp = Math.floor(new Date().getTime() / 1000) + 10 * 60;
  const whitelist2MintStartTimestamp = whitelist1MintStartTimestamp + 10 * 60;
  const publicMintStartTimestamp = whitelist2MintStartTimestamp + 20 * 60;

  const merklke1Root = "0x61ca13fc57a55588b6feda07538f2a1a514c62fbc0ab534fb5a77214ca1df545";
  const merklke2Root = merklke1Root; // FIXME

  // balance pass unrevealed metas
  const baseTokenURI = "ipfs://QmPHtTskxyEmR3yXGYdwZQWpo2Kfx27GUTqAdtDJNwyarP";
  const passNFT = await ethers.getContractFactory("BalancePass");
  //const passnft = await passNFT.attach("0xa3DDAf083e491ecd5CbdCbd7DcC504cA7c0f2408"); // rinkeby
  //const passnft = await passNFT.attach("0x2fd0ff45263143dcd616ecada45c0d22e49adbb7"); // mainnet
  const passnft = await passNFT.deploy(maxMint, maxMintWalletLimit, baseTokenURI, whitelist1MintStartTimestamp, whitelist2MintStartTimestamp, publicMintStartTimestamp, merklke1Root, merklke2Root);
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
