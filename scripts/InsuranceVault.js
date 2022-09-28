const { ethers } = require("hardhat");

async function main() {
  let [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account: " + deployer.address);

  const network = "rinkeby";
  // const network = "fantom_testnet";
  const {
    daiAddress,
    usdcAddress,
    usdbAddress,
  } = require(`./networks-${network}.json`);

  const InsuranceVaultTemplate = await ethers.getContractFactory(
    "InsuranceVault"
  );
  const balanceVaultTemplate = await InsuranceVaultTemplate.deploy();
  console.log(
    `Deployed InsuranceVaultTemplate to: ${balanceVaultTemplate.address}`
  );
  console.log(
    `\nVerify:\nnpx hardhat verify --network ${network} ${balanceVaultTemplate.address}`
  );

  const InsuranceVaultManager = await ethers.getContractFactory(
    "InsuranceVaultManager"
  );
  const balanceVaultManager = await InsuranceVaultManager.deploy(
    daiAddress,
    usdbAddress,
    usdcAddress
  );
  console.log(
    `Deployed InsuranceVaultManager to: ${balanceVaultManager.address}`
  );
  console.log(
    `\nVerify:\nnpx hardhat verify --network ${network} ${balanceVaultManager.address} ${daiAddress} ${usdbAddress} ${usdcAddress}`
  );
}

main()
  .then(() => process.exit())
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
