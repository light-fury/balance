const { ethers } = require("hardhat");

async function main() {
  const network = "goerli";
  const { usdbAddress } = require(`./networks-${network}.json`);

  const InsuranceVaultManager = await ethers.getContractFactory(
    "InsuranceVaultManager"
  );
  const balanceVaultManager = await InsuranceVaultManager.deploy(usdbAddress);
  console.log(
    `Deployed InsuranceVaultManager to: ${balanceVaultManager.address}`
  );
  console.log(
    `Verify:\nnpx hardhat verify --network ${network} ${balanceVaultManager.address} ${usdbAddress}`
  );

  const InsuranceVaultTemplate = await ethers.getContractFactory(
    "InsuranceVault"
  );
  const balanceVaultTemplate = await InsuranceVaultTemplate.deploy();
  console.log(
    `Deployed InsuranceVaultTemplate to: ${balanceVaultTemplate.address}`
  );
  console.log(
    `Verify:\nnpx hardhat verify --network ${network} ${balanceVaultTemplate.address}\n`
  );

  await balanceVaultManager.setVaultTemplate(balanceVaultTemplate.address);
}

main()
  .then(() => process.exit())
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
