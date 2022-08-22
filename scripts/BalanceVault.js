const { ethers } = require("hardhat");

async function main() {

    let [deployer] = await ethers.getSigners();
    console.log('Deploying contracts with the account: ' + deployer.address);

    const network = "rinkeby";
    // const network = "fantom_testnet";
    const {
        daoAddress,
        usdbAddress,
    } = require(`./networks-${network}.json`);

    const BalanceVaultTemplate = await ethers.getContractFactory('BalanceVault');
    const balanceVaultTemplate = await BalanceVaultTemplate.attach("0xB3E54eca065F441Cc23d9698b551A4C0Cb662a08");
    // const balanceVaultTemplate = await BalanceVaultTemplate.deploy();
    console.log(`Deployed BalanceVaultTemplate to: ${balanceVaultTemplate.address}`);
    console.log(`\nVerify:\nnpx hardhat verify --network ${network} ${balanceVaultTemplate.address}`);

    const BalanceVaultShareTemplate = await ethers.getContractFactory('BalanceVaultShare');
    const balanceVaultShareTemplate = await BalanceVaultShareTemplate.attach("0xDBee21F992Cf46517190cE248970730673B7017f");
    // const balanceVaultShareTemplate = await BalanceVaultShareTemplate.deploy();
    console.log(`Deployed BalanceVaultShareTemplate to: ${balanceVaultShareTemplate.address}`);
    console.log(`\nVerify:\nnpx hardhat verify --network ${network} ${balanceVaultShareTemplate.address}`);

    const feeBorrower = 500;
    const feeLenderUsdb = 1500;
    const feeLenderOther = 2000;

    const BalanceVaultManager = await ethers.getContractFactory('BalanceVaultManager');
    const balanceVaultManager = await BalanceVaultManager.attach("0xd2Ac4647107886ed9d3051aD4B823c7A80d9de40");
    // const balanceVaultManager = await BalanceVaultManager.deploy(daoAddress, usdbAddress, feeBorrower, feeLenderUsdb, feeLenderOther);
    console.log(`Deployed BalanceVaultManager to: ${balanceVaultManager.address}`);

    await balanceVaultManager.setVaultTemplate("0xB3E54eca065F441Cc23d9698b551A4C0Cb662a08");
    await balanceVaultManager.setNftTemplate("0xDBee21F992Cf46517190cE248970730673B7017f");

    console.log(`\nVerify:\nnpx hardhat verify --network ${network} `+
        `${balanceVaultManager.address} "${daoAddress}" "${usdbAddress}" ${feeBorrower} ${feeLenderUsdb} ${feeLenderOther}`);
}

main()
    .then(() => process.exit())
    .catch(error => {
        console.error(error);
        process.exit(1);
})
