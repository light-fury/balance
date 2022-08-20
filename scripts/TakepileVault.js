const { ethers } = require("hardhat");

async function main() {

    let [deployer] = await ethers.getSigners();
    console.log('Deploying contracts with the account: ' + deployer.address);

    const network = "rinkeby";
    // const network = "fantom_testnet";
    const {
        fhmCirculatingSupply,
    } = require(`./networks-${network}.json`);

    const TakepileVault = await ethers.getContractFactory('TakepileVault');
    const takepileVault = await TakepileVault.deploy(fhmCirculatingSupply);
    console.log(`Deployed TakepileVault to: ${takepileVault.address}`);

    console.log(`\nVerify:\nnpx hardhat verify --network ${network} `+
        `${takepileVault.address} "${fhmCirculatingSupply}"`);
}

main()
    .then(() => process.exit())
    .catch(error => {
        console.error(error);
        process.exit(1);
})
