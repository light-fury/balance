const { ethers } = require("hardhat");

async function main() {
  let [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account: " + deployer.address);

  const network = "rinkeby";
  // const network = "fantom_testnet";
  const { daoAddress, usdbAddress } = require(`./networks-${network}.json`);

  const BalanceVaultTemplate = await ethers.getContractFactory("BalanceVault");
  // const balanceVaultTemplate = await BalanceVaultTemplate.attach("0xc0734dd0EeF485eAB9118e3d6Ff8011bB3C141eA");
  const balanceVaultTemplate = await BalanceVaultTemplate.deploy();
  console.log(
    `Deployed BalanceVaultTemplate to: ${balanceVaultTemplate.address}`
  );
  console.log(
    `\nVerify:\nnpx hardhat verify --network ${network} ${balanceVaultTemplate.address}`
  );

  // const BalanceVaultShareTemplate = await ethers.getContractFactory('BalanceVaultShare');
  // // const balanceVaultShareTemplate = await BalanceVaultShareTemplate.attach("0x4bF4a98a8A96b2270D877cA9af035715F2A128aB");
  // const balanceVaultShareTemplate = await BalanceVaultShareTemplate.deploy();
  // console.log(`Deployed BalanceVaultShareTemplate to: ${balanceVaultShareTemplate.address}`);
  // console.log(`\nVerify:\nnpx hardhat verify --network ${network} ${balanceVaultShareTemplate.address}`);

  // const feeBorrower = 500;
  // const feeLenderUsdb = 1500;
  // const feeLenderOther = 2000;
  //
  // const BalanceVaultManager = await ethers.getContractFactory('BalanceVaultManager');
  // // const balanceVaultManager = await BalanceVaultManager.attach("0x95d18604957ed8689dC3aB6BC7E2ABDCaf81A8eE");
  // const balanceVaultManager = await BalanceVaultManager.deploy(daoAddress, usdbAddress, feeBorrower, feeLenderUsdb, feeLenderOther);
  // console.log(`Deployed BalanceVaultManager to: ${balanceVaultManager.address}`);

  // await balanceVaultManager.setVaultTemplate("0xc0734dd0EeF485eAB9118e3d6Ff8011bB3C141eA");
  // await balanceVaultManager.setNftTemplate("0x4bF4a98a8A96b2270D877cA9af035715F2A128aB");

  // console.log(`\nVerify:\nnpx hardhat verify --network ${network} `+
  //     `${balanceVaultManager.address} "${daoAddress}" "${usdbAddress}" ${feeBorrower} ${feeLenderUsdb} ${feeLenderOther}`);

  // const BalancePassManager = await ethers.getContractFactory('BalancePassManager');
  // // const balancePassManager = await BalanceVaultTemplate.attach("0x0993C3f7F1ADB0af8CBcbce0fa43Db5068edA991");
  // const balancePassManager = await BalancePassManager.deploy();
  // console.log(`Deployed BalancePassManager to: ${balancePassManager.address}`);
  // console.log(`\nVerify:\nnpx hardhat verify --network ${network} ${balancePassManager.address}`);

  // const OffChainBalancePassHolderStrategy = await ethers.getContractFactory('OffChainBalancePassHolderStrategy');
  // // const offChainBalancePassHolderStrategy = await BalanceVaultTemplate.attach("0x629f17887785612Cd7C5cea6441c0869c0F96eCd");
  // const offChainBalancePassHolderStrategy = await OffChainBalancePassHolderStrategy.deploy();
  // console.log(`Deployed OffChainBalancePassHolderStrategy to: ${offChainBalancePassHolderStrategy.address}`);
  // console.log(`\nVerify:\nnpx hardhat verify --network ${network} ${offChainBalancePassHolderStrategy.address}`);
}

main()
  .then(() => process.exit())
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
