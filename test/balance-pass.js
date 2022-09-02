const { expect } = require("chai");
const { ethers, waffle } = require("hardhat");
const keccak256 = require("keccak256");
const { default: MerkleTree } = require("merkletreejs");

describe("Token contract", function () {
  let owner, nonOwner, inRoot, notInRoot;
  const maxMint = 350;
  const maxWalletLimit = 1;
  const whitelistMintStatus = true;
  const baseTokenURI = "ipfs://Qmc8A19qUxy1VWeSDtJj9cGk1DAfE88E47Xb5BFn5Z6Hg1";
  const nftName = "BalancePass";
  const nftSymbol = "BALANCE-PASS";

  const provider = waffle.provider;
  let passNft;

  before(async () => {
    [owner, nonOwner, inRoot, notInRoot] = await ethers.getSigners();
    const merkleRoot = getRootHash(getMerkleTree([owner.address, nonOwner.address, inRoot.address]));
    const PassNft = await ethers.getContractFactory("BalancePass");
    passNft = await PassNft.deploy(maxMint, maxWalletLimit, baseTokenURI, whitelistMintStatus, merkleRoot, merkleRoot);
  });
  
  it("Validate basics", async function () {
    expect(await passNft.name()).to.equal(nftName);
    expect(await passNft.symbol()).to.equal(nftSymbol);
    expect(await passNft.baseURI()).to.equal(baseTokenURI);
  });

  it("Validate primary whitelist can mint", async function () {
    const merkleTree = getMerkleTree([owner.address, nonOwner.address, inRoot.address]);
    const proof1 = getProof(owner.address, merkleTree);

    await passNft.mint_whitelist_gh56gui(proof1);
    const walletOfOwner = await passNft.tokensOfOwner(owner.address);
    expect(walletOfOwner[0].toNumber()).to.equal(0);
  });

  // validate mint limit
  it("Should only be allowed to mint 1", async function () {
    const merkleTree = getMerkleTree([owner.address, nonOwner.address, inRoot.address]);
    const proof1 = getProof(owner.address, merkleTree)
    await expect(passNft.mint_whitelist_gh56gui(proof1)).to.be.revertedWith("BalancePass: Max wallet limit reached");
  });

// set base uri
it("Owner should be able to change base uri", async function () {
  const newBaseUri = "ipfs://Qmc8A19qUxy1VWeSDtJj9cGk1";
  await passNft.setBaseURI(newBaseUri);
  expect(await passNft.baseTokenURI()).to.equal(newBaseUri);
  await passNft.setBaseURI(baseTokenURI);
});

it("Non owner should not be able to change base uri", async function () {
  const newBaseUri = "ipfs://Qmc8A19qUxy1VWeSDtJj9cGk1";
  await expect(passNft.connect(nonOwner).setBaseURI(newBaseUri)).to.be.revertedWith("Ownable: caller is not the owner");
});

// set max mint
// set base uri
it("Owner should be able to change max mint", async function () {
  const newMax = 500;
  await passNft.setMaxMint(newMax);
  await passNft.setMaxMint(350);
});

it("Non-owner should NOT be able to change max mint", async function () {
  const newMax = 500;
  await expect(passNft.connect(nonOwner).setMaxMint(newMax)).to.be.revertedWith("Ownable: caller is not the owner");
});

// setmaxmintwalletlimit
it("Owner should be able to change max wallet limit", async function () {
  const newMax = 5;
  await passNft.setMaxMintWalletLimit(newMax);
  await passNft.setMaxMintWalletLimit(1);
});

it("Non-owner should NOT be able to change max wallet limit", async function () {
  const newMax = 500;
  await expect(passNft.connect(nonOwner).setMaxMintWalletLimit(newMax)).to.be.revertedWith("Ownable: caller is not the owner");
});

// set token type + // get token type

// set whitelist1root
it("Owner should be able to change whitelist 1", async function () {
  const newMax = 5;
  await passNft.setWhitelist1Root(getRootHash(getMerkleTree([owner.address, inRoot.address])));
});

it("Non-Owner should not be able to change whitelist 1", async function () {
  const newMax = 500;
  await expect(passNft.connect(nonOwner)
    .setWhitelist1Root(getRootHash(getMerkleTree([owner.address, inRoot.address]))))
    .to.be.revertedWith("Ownable: caller is not the owner");
});

// set whitelist2root
it("Owner should be able to change whitelist 2", async function () {
  const newMax = 5;
  await passNft.setWhitelist2Root(getRootHash(getMerkleTree([owner.address, inRoot.address])));
});

it("Non-Owner should not be able to change whitelist 2", async function () {
  const newMax = 500;
  await expect(passNft.connect(nonOwner)
    .setWhitelist2Root(getRootHash(getMerkleTree([owner.address, inRoot.address]))))
    .to.be.revertedWith("Ownable: caller is not the owner");
});

// set whitelistmint status
it("Owner should be able to change set whitelist status", async function () {
  await passNft.setWhitelistMintStatus(false);
});

it("Non-Owner should not set whitelist status", async function () {
  const newMax = 500;
  await expect(passNft.connect(nonOwner)
    .setWhitelistMintStatus(false))
    .to.be.revertedWith("Ownable: caller is not the owner");
});

// mint secondary

// mint public

// validate token uri

// validate current token id

// transferFrom
});

const getMerkleTree = (includeAddressArry) => {
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

    const leafNodes = whiteListAddresses.concat(includeAddressArry).map(addr => keccak256(addr));
    const merkleTree = new MerkleTree(leafNodes, keccak256, {sortPairs: true});
    return merkleTree;
}


const getProof = (address, merkleTree) => {
  const hashedAddress = keccak256(address);
  const proof = merkleTree.getHexProof(hashedAddress);
  return proof;
}

const getRootHash = (merkleTree) => {
  const rootHash = merkleTree.getRoot();
  return `0x${rootHash.toString('hex')}`;
}