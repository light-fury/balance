const { ethers } = require("hardhat");

async function main() {
  let [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account: " + deployer.address);

  // const network = "rinkeby";
  const network = "mainnet";

  const maxMint = 350;
  const maxMintWalletLimit = 1;

  // FIXME prod values are WL1 = Mon 9/5 18:00 UTC, WL2 = WL1 + 1hour, public = WL2 + 1hour
  // const whitelist1MintStartTimestamp = Math.floor(new Date().getTime() / 1000) + 20 * 60;
  // const whitelist2MintStartTimestamp = whitelist1MintStartTimestamp + 20 * 60;
  // const publicMintStartTimestamp = whitelist2MintStartTimestamp + 20 * 60;
  const whitelist1MintStartTimestamp = 1662400800;
  const whitelist2MintStartTimestamp = 1662404400;
  const publicMintStartTimestamp = 1662411600;

  const merklke1Root =
    "0x1b884ee93096fd286f2cd284508b72dcd747a62e09a0aca80bb4dd783606f67d";
  const merklke2Root =
    "0x1bc5865dcee5e3b1a0cb77568d6e324cff399d2c1fa32543386e5aa2cd2d0948";

  // balance pass unrevealed metas
  // const baseTokenURI = "ipfs://QmPHtTskxyEmR3yXGYdwZQWpo2Kfx27GUTqAdtDJNwyarP"; // pre-reveal
  const baseTokenURI = "ipfs://QmTSoogm5rkR2sUaZUWj2cLcJJdzUJZrHfBNFGp9vMGLAu"; // post-reveal
  const passNFT = await ethers.getContractFactory("BalancePass");
  //const passnft = await passNFT.attach("0xD69e023bfC1408b3202c79667253B0b6b68C60c0"); // rinkeby
  //const passnft = await passNFT.attach("0x3707CFddaE348F05bAEFD42406ffBa4B74Ec8D91"); // mainnet
  const passnft = await passNFT.deploy(
    maxMint,
    maxMintWalletLimit,
    baseTokenURI,
    whitelist1MintStartTimestamp,
    whitelist2MintStartTimestamp,
    publicMintStartTimestamp,
    merklke1Root,
    merklke2Root
  );
  console.log(`Deployed liqdnft to: ${passnft.address}`);

  console.log(
    `\nVerify:\nnpx hardhat verify --network ${network} ` +
      `${passnft.address} "${maxMint}" "${maxMintWalletLimit}" "${baseTokenURI}" "${whitelist1MintStartTimestamp}" "${whitelist2MintStartTimestamp}" "${publicMintStartTimestamp}" "${merklke1Root}" "${merklke2Root}"`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
