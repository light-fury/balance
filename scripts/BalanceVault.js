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

    // const BalanceVaultTemplate = await ethers.getContractFactory('BalanceVault');
    // // const balanceVaultTemplate = await BalanceVaultTemplate.attach("0x0e04Ab78Ed835808bd85a35b586BFcE8f4AB118c");
    // const balanceVaultTemplate = await BalanceVaultTemplate.deploy();
    // console.log(`Deployed BalanceVaultTemplate to: ${balanceVaultTemplate.address}`);
    // console.log(`\nVerify:\nnpx hardhat verify --network ${network} ${balanceVaultTemplate.address}`);

    // const BalanceVaultShareTemplate = await ethers.getContractFactory('BalanceVaultShare');
    // // const balanceVaultShareTemplate = await BalanceVaultShareTemplate.attach("0x0650e17235b4B364c8432b927E6f190394A24bcB");
    // const balanceVaultShareTemplate = await BalanceVaultShareTemplate.deploy();
    // console.log(`Deployed BalanceVaultShareTemplate to: ${balanceVaultShareTemplate.address}`);
    // console.log(`\nVerify:\nnpx hardhat verify --network ${network} ${balanceVaultShareTemplate.address}`);

    const feeBorrower = 500;
    const feeLenderUsdb = 1500;
    const feeLenderOther = 2000;

    const BalanceVaultManager = await ethers.getContractFactory('BalanceVaultManager');
    // const balanceVaultManager = await BalanceVaultManager.attach("0xA1fd7c7da83e726276b9D312949BD2ECb08994BB");
    const balanceVaultManager = await BalanceVaultManager.deploy(daoAddress, usdbAddress, feeBorrower, feeLenderUsdb, feeLenderOther);
    console.log(`Deployed BalanceVaultManager to: ${balanceVaultManager.address}`);

    // await balanceVaultManager.setVaultTemplate("0x0e04Ab78Ed835808bd85a35b586BFcE8f4AB118c");
    // await balanceVaultManager.setNftTemplate("0x0650e17235b4B364c8432b927E6f190394A24bcB");

    console.log(`\nVerify:\nnpx hardhat verify --network ${network} `+
        `${balanceVaultManager.address} "${daoAddress}" "${usdbAddress}" ${feeBorrower} ${feeLenderUsdb} ${feeLenderOther}`);
}

main()
    .then(() => process.exit())
    .catch(error => {
        console.error(error);
        process.exit(1);
})
