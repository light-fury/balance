import { ethers } from "hardhat";

async function main() {
  let [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account: " + deployer.address);

  // const network = "goerli";
  const network = "mainnet";
  const setter = "0x994cd376c9E8D9b8075bE15E6a9AfA9b79eBAaC2";

  const BalanceMerkleDistributor = await ethers.getContractFactory("BalanceMerkleDistributor");
  // const balanceMerkleDistributor = await BalanceMerkleDistributor.attach("0x10dbE1A3c4946e50517795e53a3789C793bEb295");
  const balanceMerkleDistributor = await BalanceMerkleDistributor.deploy(setter);
  console.log(
    `Deployed BalanceMerkleDistributor to: ${balanceMerkleDistributor.address}`
  );
  console.log(
    `\nVerify:\nnpx hardhat verify --network ${network} ${balanceMerkleDistributor.address} ${setter}`
  );
}

main()
  .then(() => process.exit())
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
