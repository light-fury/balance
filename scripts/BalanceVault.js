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
    // // const balanceVaultTemplate = await BalanceVaultTemplate.attach("0x9Cddcf1a4df75fE9606A22b903Ca345DB325feb1");
    // const balanceVaultTemplate = await BalanceVaultTemplate.deploy();
    // console.log(`Deployed BalanceVaultTemplate to: ${balanceVaultTemplate.address}`);
    // console.log(`\nVerify:\nnpx hardhat verify --network ${network} ${balanceVaultTemplate.address}`);

    const BalanceVaultShareTemplate = await ethers.getContractFactory('BalanceVaultShare');
    // const balanceVaultShareTemplate = await BalanceVaultShareTemplate.attach("0xEA4E5044D038fB484434b787FB59741cC6AE53cc");
    const balanceVaultShareTemplate = await BalanceVaultShareTemplate.deploy();
    console.log(`Deployed BalanceVaultShareTemplate to: ${balanceVaultShareTemplate.address}`);
    console.log(`\nVerify:\nnpx hardhat verify --network ${network} ${balanceVaultShareTemplate.address}`);

    // const feeBorrower = 500;
    // const feeLenderUsdb = 1500;
    // const feeLenderOther = 2000;
    //
    // const BalanceVaultManager = await ethers.getContractFactory('BalanceVaultManager');
    // const balanceVaultManager = await BalanceVaultManager.attach("0x096b2588e00A1D4258D2384E4B268393de260215");
    // // const balanceVaultManager = await BalanceVaultManager.deploy(daoAddress, usdbAddress, feeBorrower, feeLenderUsdb, feeLenderOther);
    // console.log(`Deployed BalanceVaultManager to: ${balanceVaultManager.address}`);
    //
    // await balanceVaultManager.setVaultTemplate("0x9Cddcf1a4df75fE9606A22b903Ca345DB325feb1");
    // await balanceVaultManager.setNftTemplate("0xEA4E5044D038fB484434b787FB59741cC6AE53cc");
    // //
    // console.log(`\nVerify:\nnpx hardhat verify --network ${network} `+
    //     `${balanceVaultManager.address} "${daoAddress}" "${usdbAddress}" ${feeBorrower} ${feeLenderUsdb} ${feeLenderOther}`);
}

main()
    .then(() => process.exit())
    .catch(error => {
        console.error(error);
        process.exit(1);
})
