const { expect } = require("chai");
const { ethers, waffle } = require("hardhat");
const keccak256 = require("keccak256");
const { default: MerkleTree } = require("merkletreejs");

describe("Token contract", function () {
  let owner, nonOwner, inRoot, notInRoot;
  const maxMint = 350;
  const maxWalletLimit = 1;
  const baseTokenURI = "ipfs://QmPHtTskxyEmR3yXGYdwZQWpo2Kfx27GUTqAdtDJNwyarP";
  const nftName = "Balance Pass";
  const nftSymbol = "BALANCE-PASS";

  const provider = waffle.provider;
  let passNft;
  let wl1MintTimestamp;
  let wl2MintTimestamp;
  let publicMintTimestamp;

  before(async () => {
    [owner, nonOwner, inRoot, notInRoot] = await ethers.getSigners();
    const merkleRoot = getRootHash(getMerkleTree([owner.address, nonOwner.address, inRoot.address]));
    const PassNft = await ethers.getContractFactory("BalancePass");

    // wl1 mint starts after 30min
    wl1MintTimestamp = Math.floor(new Date().getTime() / 1000) + 30 * 60;
    // wl2 mint starts an hour after wl1
    wl2MintTimestamp = wl1MintTimestamp + 60 * 60;
    // public mint starts 2 hours after wl2
    publicMintTimestamp = wl2MintTimestamp + 2 * 60 * 60;
    // console.log(`Using: wl1ts: ${wl1MintTimestamp}, wl2ts: ${wl2MintTimestamp}, public: ${publicMintTimestamp}`);

    passNft = await PassNft.deploy(maxMint, maxWalletLimit, baseTokenURI, wl1MintTimestamp, wl2MintTimestamp, publicMintTimestamp, merkleRoot, merkleRoot);
  });

  it("Validate basics", async function () {
    expect(await passNft.name()).to.equal(nftName);
    expect(await passNft.symbol()).to.equal(nftSymbol);
    expect(await passNft.baseURI()).to.equal(baseTokenURI);
  });

  ///
  /// minting logic
  ///

  it("Cannot mint wl1 in time 0", async function () {
    const merkleTree = getMerkleTree([owner.address, nonOwner.address, inRoot.address]);
    const proof1 = getProof(owner.address, merkleTree);
    await expect(passNft.mint_whitelist1(proof1)).to.be.revertedWith("WHITELIST1_MINT_DIDNT_START");
  });

  it("Cannot mint wl2 in time 0", async function () {
    const merkleTree = getMerkleTree([owner.address, nonOwner.address, inRoot.address]);
    const proof1 = getProof(owner.address, merkleTree);
    await expect(passNft.mint_whitelist2(proof1)).to.be.revertedWith("WHITELIST2_MINT_DIDNT_START");
  });

  it("Cannot mint public in time 0", async function () {
    await expect(passNft.mint_public()).to.be.revertedWith("PUBLIC_MINT_DIDNT_START");
  });

  it("Validate primary whitelist can mint", async function () {
    // move time to wl1
    await ethers.provider.send('evm_increaseTime', [30 * 60]);

    const merkleTree = getMerkleTree([owner.address, nonOwner.address, inRoot.address]);
    const proof1 = getProof(owner.address, merkleTree);
    await passNft.mint_whitelist1(proof1);
    const walletOfOwner = await passNft.tokensOfOwner(owner.address);
    expect(walletOfOwner[walletOfOwner.length - 1].toNumber()).to.equal(0);
  });

  // validate mint limit
  it("Should only be allowed to mint 1 in wl1", async function () {
    const merkleTree = getMerkleTree([owner.address, nonOwner.address, inRoot.address]);
    const proof1 = getProof(owner.address, merkleTree)
    await expect(passNft.mint_whitelist1(proof1)).to.be.revertedWith("MAX_WALLET_LIMIT_REACHED");
  });

  it("Cannot mint wl2 in time wl1", async function () {
    const merkleTree = getMerkleTree([owner.address, nonOwner.address, inRoot.address]);
    const proof1 = getProof(owner.address, merkleTree);
    await expect(passNft.mint_whitelist2(proof1)).to.be.revertedWith("WHITELIST2_MINT_DIDNT_START");
  });

  it("Cannot mint public in time wl1", async function () {
    await expect(passNft.mint_public()).to.be.revertedWith("PUBLIC_MINT_DIDNT_START");
  });

  it("Validate secondary whitelist can mint", async function () {
    // move time to wl2
    await ethers.provider.send('evm_increaseTime', [60 * 60]);

    const merkleTree = getMerkleTree([owner.address, nonOwner.address, inRoot.address]);
    const proof2 = getProof(nonOwner.address, merkleTree);
    await passNft.connect(nonOwner).mint_whitelist2(proof2);
    const walletOfNonOwner = await passNft.tokensOfOwner(nonOwner.address);
    expect(walletOfNonOwner[walletOfNonOwner.length - 1].toNumber()).to.equal(1);
  });

  it("Cannot mint wl1 in time wl2", async function () {
    const merkleTree = getMerkleTree([owner.address, nonOwner.address, inRoot.address]);
    const proof1 = getProof(owner.address, merkleTree);
    await expect(passNft.mint_whitelist1(proof1)).to.be.revertedWith("WHITELIST1_MINT_DIDNT_START");
  });

  it("Cannot mint public in time wl2", async function () {
    await expect(passNft.mint_public()).to.be.revertedWith("PUBLIC_MINT_DIDNT_START");
  });

  it("Should only be allowed to mint 1 in wl2", async function () {
    const merkleTree = getMerkleTree([owner.address, nonOwner.address, inRoot.address]);
    const proof2 = getProof(nonOwner.address, merkleTree)
    await expect(passNft.connect(nonOwner).mint_whitelist2(proof2)).to.be.revertedWith("MAX_WALLET_LIMIT_REACHED");
  });

  it("Validate any user can mint", async function () {
    // move time to wl2
    await ethers.provider.send('evm_increaseTime', [2 * 60 * 60]);

    await passNft.connect(inRoot).mint_public();
    const walletOfInRoot = await passNft.tokensOfOwner(inRoot.address);
    expect(walletOfInRoot[walletOfInRoot.length - 1].toNumber()).to.equal(2);
  });

  it("Should only be allowed to mint 1 in public", async function () {
    await expect(passNft.connect(inRoot).mint_public()).to.be.revertedWith("MAX_WALLET_LIMIT_REACHED");
  });

  it("Cannot mint wl1 in time public", async function () {
    const merkleTree = getMerkleTree([owner.address, nonOwner.address, inRoot.address]);
    const proof1 = getProof(owner.address, merkleTree);
    await expect(passNft.mint_whitelist1(proof1)).to.be.revertedWith("WHITELIST1_MINT_DIDNT_START");
  });

  it("Cannot mint wl2 in time public", async function () {
    const merkleTree = getMerkleTree([owner.address, nonOwner.address, inRoot.address]);
    const proof1 = getProof(owner.address, merkleTree);
    await expect(passNft.mint_whitelist2(proof1)).to.be.revertedWith("WHITELIST2_MINT_DIDNT_START");
  });

  ///
  /// management logic
  ///

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

  it("Reveal token types", async function () {
    // Platinum
    await passNft.setTokenType([[0, 1], [5, 7]], 2);
    // Gold
    await passNft.setTokenType([[2, 4]], 1);
    // Genesis
    await passNft.setTokenType([[8, 10], [11, 350]], 0);
  });

  it("Get proper token type", async function () {
	  const platinumArray = [0, 1, 5, 6, 7];
	  const goldArray = [2, 3, 4];

	  for (let i = 0; i < platinumArray.length; i++) {
		  expect(await passNft.getTokenType(platinumArray[i])).to.is.eq("Platinum");
	  }
	  for (let i = 0; i < goldArray.length; i++) {
		  expect(await passNft.getTokenType(goldArray[i])).to.is.eq("Gold");
	  }
	  for (let i = 0; i < 11 /* can be same for 350, but longer */; i++) {
		  if (platinumArray.indexOf(i) !== -1) continue;
		  if (goldArray.indexOf(i) !== -1) continue;

		  expect(await passNft.getTokenType(i)).to.is.eq("Genesis");
	  }
  });

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

  // validate token uri
  it("Token uri should provide expected uri", async function () {
    expect(await passNft.tokenURI(0)).to.equal(`${baseTokenURI}/0.json`);
  });

  // validate current token id
  it("Current token Id should be +1 the last one generated", async function () {
    expect(await passNft.currentTokenId()).to.equal(3);
  });

  // transferFrom
  // ownerOf
  it("Should be able to transfer tokens between wallets", async function () {
    const from = owner.address;
    const to = nonOwner.address;
    const tokenId = 0;
    await passNft.transferFrom(from, to, tokenId);
    expect(await passNft.ownerOf(tokenId)).to.equal(to);
  });

  // additional tests to write
  // ERC721a: https://github.com/chiru-labs/ERC721A/blob/main/contracts/IERC721A.sol
  // totalsupply
  // supportsInterface
  // balanceOf
  // safeTransferFrom
  // approve
  // setApprovalForAll
  // getApprove
  // isApprovedForAll

  // ERC721aQueryable: https://github.com/chiru-labs/ERC721A/blob/main/contracts/extensions/IERC721AQueryable.sol
  // explicitOwnershipOf
  // explicitOwnershipsOf
  // tokensOfOwnerIn
  // tokensOfOwner
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