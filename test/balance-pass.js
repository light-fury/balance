const { expect } = require("chai");
const { ethers, waffle } = require("hardhat");
const keccak256 = require("keccak256");
const { default: MerkleTree } = require("merkletreejs");

describe("Token contract", function () {
  let owner;
  const maxMint = 350;
  const baseTokenURI = "ipfs://Qmc8A19qUxy1VWeSDtJj9cGk1DAfE88E47Xb5BFn5Z6Hg1";
  const nftName = "BalancePass";
  const nftSymbol = "BALANCE-PASS";

  const provider = waffle.provider;
  let passNft;

  before(async () => {
    const merkleRoot = getMerkleTree().getRoot();
    [owner] = await ethers.getSigners();
    const PassNft = await ethers.getContractFactory("BalancePass");
    passNft = await PassNft.deploy(maxMint, baseTokenURI, true, merkleRoot);
  });
  
  it("Validate basics", async function () {
    expect(await passNft.name()).to.equal(nftName);
    expect(await passNft.symbol()).to.equal(nftSymbol);
    expect(await passNft.baseURI()).to.equal(baseTokenURI);
  });

  it("Validate whitelist", async function () {
    const whitelistAddress1 = "0x45fFb7aC7bC4eF4Fe1A095C71EcFc237523355e7";
    const whitelistAddress2 = "0x1667cC75D4E52a5cCe71cDb25606Dcaf5B625264";
    const merkleTree = getMerkleTree();

    const proof1 = getProof(whitelistAddress1, merkleTree);
    console.log(proof1);

    await passNft.mint_whitelist_gh56gui(proof1);
    const walletOfOwner = await passNft.walletOfOwner(owner.address);
    expect(walletOfOwner[0].eq(1)).to.equal(true);
  });
});


const getProof = (address, merkleTree) => {
  const hashedAddress = keccak256(address);
  const proof = merkleTree.getHexProof(hashedAddress);
  return proof;
}

const getMerkleTree = () => {
  const whiteListAddresses = [
    "0x45fFb7aC7bC4eF4Fe1A095C71EcFc237523355e7",
    "0x1667cC75D4E52a5cCe71cDb25606Dcaf5B625264",
    "0x0F26e3C772BFeB5694517451875F30Bd5931487F",
    "0xFd86a0D88155e9DEAF274df8F7dEf9D8A2054dDD",
    "0x6F1AB7d800Dc9D2abcC493aDCe369d87178057F1",
    "0x24a6Dc4d30A41feB5b03C64aFa09d72e8891B06f",
    "0x5108cB1f3A3Eb700D1B57FE54691BBb9734B5C85",
    "0xb236f9f249390038CC3C4E7EC6a6260e8540AEe0",
    "0x8480D5026d12AD81d9c1B5fbD40962d5c454f228",
    "0xc8D127C56d05dad30cE91F388de3FD65645dd9CA",
    "0x7a25Fc65aa566796790cf1567a5044020734CD50",
  ];

    const leafNodes = whiteListAddresses.map(addr => keccak256(addr));
    const merkleTree = new MerkleTree(leafNodes, keccak256, {sortPairs: true});
    return merkleTree;
}

const getRootHash = (merkleTree) => {
  const rootHash = merkleTree.getRoot();
  return rootHash.toString('hex');
}