import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { utils } from "ethers";
import { ethers, waffle } from "hardhat";
import keccak256 from "keccak256";
import MerkleTree from "merkletreejs";
import { BalanceMerkleDistributor, MockERC20 } from "../typechain-types";

describe("Balance Merkle Distributor", function () {
  let owner: SignerWithAddress;
  let setter: SignerWithAddress;
  let alice: SignerWithAddress;
  let bob: SignerWithAddress;

  let merkleDistributor: BalanceMerkleDistributor;
  let erc20Token: MockERC20;

  const ETH = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";

  beforeEach(async () => {
    [owner, setter, alice, bob] = await ethers.getSigners();

    const BalanceMerkleDistributorFactory = await ethers.getContractFactory(
      "BalanceMerkleDistributor"
    );

    merkleDistributor = await BalanceMerkleDistributorFactory.deploy(
      setter.address
    );

    const MockERC20Factory = await ethers.getContractFactory("MockERC20");

    erc20Token = await MockERC20Factory.deploy();
  });

  describe("#setMerkleRoot", () => {
    let infos = [];
    let merkleTree: MerkleTree;

    beforeEach(async () => {
      infos = [
        {
          user: alice.address,
          token: ETH,
          allocation: utils.parseEther("1"),
        },
      ];

      merkleTree = getMerkleTree(infos);
    });

    it("it reverts if msg.sender is not setter", async () => {
      await expect(
        merkleDistributor.connect(alice).setMerkleRoot(merkleTree.getRoot())
      ).revertedWith("msg.sender is not setter");
    });

    it("it sets new merkle root", async () => {
      const tx = await merkleDistributor
        .connect(setter)
        .setMerkleRoot(merkleTree.getRoot());

      expect(await merkleDistributor.merkleRoot()).to.be.equal(
        merkleTree.getHexRoot()
      );

      await expect(tx)
        .to.emit(merkleDistributor, "MerkleRootUpdated")
        .withArgs(merkleTree.getHexRoot());
    });
  });

  describe("#claim", () => {
    let infos: any[] = [];
    let merkleTree: MerkleTree;

    beforeEach(async () => {
      infos = [
        {
          user: alice.address,
          token: ETH,
          allocation: utils.parseEther("1"),
        },
        {
          user: alice.address,
          token: erc20Token.address,
          allocation: utils.parseEther("10"),
        },
        {
          user: bob.address,
          token: ETH,
          allocation: utils.parseEther("2"),
        },
      ];

      merkleTree = getMerkleTree(infos);

      await merkleDistributor
        .connect(setter)
        .setMerkleRoot(merkleTree.getRoot());

      await owner.sendTransaction({
        from: owner.address,
        to: merkleDistributor.address,
        value: utils.parseEther("100"),
      });

      await erc20Token.transfer(
        merkleDistributor.address,
        utils.parseEther("100")
      );
    });

    it("it reverts proof is invalid", async () => {
      const leave = keccak256(
        utils.defaultAbiCoder.encode(
          ["address", "address", "uint256"],
          [alice.address, erc20Token.address, infos[1].allocation]
        )
      );

      const hexProof = merkleTree.getHexProof(leave);

      await expect(
        merkleDistributor
          .connect(bob)
          .claim(erc20Token.address, infos[1].allocation, hexProof)
      ).revertedWith("invalid proof");
    });

    it("it claimes ETH through merkle tree", async () => {
      const leave = keccak256(
        utils.defaultAbiCoder.encode(
          ["address", "address", "uint256"],
          [alice.address, ETH, infos[0].allocation]
        )
      );

      const hexProof = merkleTree.getHexProof(leave);

      const allocation = infos[0].allocation;

      const balanceBefore = await alice.getBalance();

      const tx = await merkleDistributor
        .connect(alice)
        .claim(ETH, allocation, hexProof);

      const receipt = await tx.wait(1);

      const fee = receipt.gasUsed.mul(receipt.effectiveGasPrice);

      expect(await alice.getBalance()).to.be.equal(
        balanceBefore.add(allocation).sub(fee)
      );
      expect(
        await merkleDistributor.claimedAmount(alice.address, ETH)
      ).to.be.equal(allocation);

      await expect(tx)
        .to.emit(merkleDistributor, "Claimed")
        .withArgs(alice.address, ETH, allocation);
    });

    it("it claimes ERC20 through merkle tree", async () => {
      const leave = keccak256(
        utils.defaultAbiCoder.encode(
          ["address", "address", "uint256"],
          [alice.address, erc20Token.address, infos[1].allocation]
        )
      );

      const hexProof = merkleTree.getHexProof(leave);

      const allocation = infos[1].allocation;

      const tx = await merkleDistributor
        .connect(alice)
        .claim(erc20Token.address, allocation, hexProof);

      expect(await erc20Token.balanceOf(alice.address)).to.be.equal(allocation);
      expect(
        await merkleDistributor.claimedAmount(alice.address, erc20Token.address)
      ).to.be.equal(allocation);

      await expect(tx)
        .to.emit(merkleDistributor, "Claimed")
        .withArgs(alice.address, erc20Token.address, allocation);
    });

    it("it claimes nothing if no more available amount", async () => {
      const leave = keccak256(
        utils.defaultAbiCoder.encode(
          ["address", "address", "uint256"],
          [alice.address, erc20Token.address, infos[1].allocation]
        )
      );

      const hexProof = merkleTree.getHexProof(leave);

      const allocation = infos[1].allocation;

      await merkleDistributor
        .connect(alice)
        .claim(erc20Token.address, allocation, hexProof);

      await merkleDistributor
        .connect(alice)
        .claim(erc20Token.address, allocation, hexProof);

      expect(await erc20Token.balanceOf(alice.address)).to.be.equal(allocation);
      expect(
        await merkleDistributor.claimedAmount(alice.address, erc20Token.address)
      ).to.be.equal(allocation);
    });

    it("it claimes available amount", async () => {
      let leave = keccak256(
        utils.defaultAbiCoder.encode(
          ["address", "address", "uint256"],
          [alice.address, erc20Token.address, infos[1].allocation]
        )
      );

      let hexProof = merkleTree.getHexProof(leave);

      await merkleDistributor
        .connect(alice)
        .claim(erc20Token.address, infos[1].allocation, hexProof);

      infos = [
        {
          user: alice.address,
          token: ETH,
          allocation: utils.parseEther("5"),
        },
        {
          user: alice.address,
          token: erc20Token.address,
          allocation: utils.parseEther("10"),
        },
        {
          user: bob.address,
          token: ETH,
          allocation: utils.parseEther("2"),
        },
      ];

      merkleTree = getMerkleTree(infos);

      await merkleDistributor
        .connect(setter)
        .setMerkleRoot(merkleTree.getRoot());

      leave = keccak256(
        utils.defaultAbiCoder.encode(
          ["address", "address", "uint256"],
          [alice.address, erc20Token.address, infos[1].allocation]
        )
      );

      hexProof = merkleTree.getHexProof(leave);

      expect(await erc20Token.balanceOf(alice.address)).to.be.equal(
        infos[1].allocation
      );
      expect(
        await merkleDistributor.claimedAmount(alice.address, erc20Token.address)
      ).to.be.equal(infos[1].allocation);
    });
  });

  describe("#claimInBatch", () => {
    let infos: any[] = [];
    let merkleTree: MerkleTree;

    beforeEach(async () => {
      infos = [
        {
          user: alice.address,
          token: ETH,
          allocation: utils.parseEther("1"),
        },
        {
          user: alice.address,
          token: erc20Token.address,
          allocation: utils.parseEther("10"),
        },
        {
          user: bob.address,
          token: ETH,
          allocation: utils.parseEther("2"),
        },
      ];

      merkleTree = getMerkleTree(infos);

      await merkleDistributor
        .connect(setter)
        .setMerkleRoot(merkleTree.getRoot());

      await owner.sendTransaction({
        from: owner.address,
        to: merkleDistributor.address,
        value: utils.parseEther("100"),
      });

      await erc20Token.transfer(
        merkleDistributor.address,
        utils.parseEther("100")
      );
    });

    it("it claimes multiple currencies", async () => {
      const leave0 = keccak256(
        utils.defaultAbiCoder.encode(
          ["address", "address", "uint256"],
          [alice.address, ETH, infos[0].allocation]
        )
      );
      const leave1 = keccak256(
        utils.defaultAbiCoder.encode(
          ["address", "address", "uint256"],
          [alice.address, erc20Token.address, infos[1].allocation]
        )
      );

      const hexProof0 = merkleTree.getHexProof(leave0);
      const hexProof1 = merkleTree.getHexProof(leave1);

      const balanceBefore0 = await alice.getBalance();

      const tx = await merkleDistributor
        .connect(alice)
        .claimInBatch(
          [ETH, erc20Token.address],
          [infos[0].allocation, infos[1].allocation],
          [hexProof0, hexProof1]
        );

      const receipt = await tx.wait(1);

      const fee = receipt.gasUsed.mul(receipt.effectiveGasPrice);

      expect(await alice.getBalance()).to.be.equal(
        balanceBefore0.add(infos[0].allocation).sub(fee)
      );
      expect(await erc20Token.balanceOf(alice.address)).to.be.equal(
        infos[1].allocation
      );
      expect(
        await merkleDistributor.claimedAmount(alice.address, ETH)
      ).to.be.equal(infos[0].allocation);
      expect(
        await merkleDistributor.claimedAmount(alice.address, erc20Token.address)
      ).to.be.equal(infos[1].allocation);

      await expect(tx)
        .to.emit(merkleDistributor, "Claimed")
        .withArgs(alice.address, ETH, infos[0].allocation);
      await expect(tx)
        .to.emit(merkleDistributor, "Claimed")
        .withArgs(alice.address, erc20Token.address, infos[1].allocation);
    });
  });

  describe("#setSetter", () => {
    it("it reverts if msg.sender is not owner", async () => {
      await expect(
        merkleDistributor.connect(setter).setSetter(alice.address)
      ).revertedWith("Ownable: caller is not the owner");
    });

    it("it updates new setter", async () => {
      await merkleDistributor.connect(owner).setSetter(alice.address);

      expect(await merkleDistributor.setter()).to.be.equal(alice.address);
    });
  });

  describe("#recoverToken", () => {
    beforeEach(async () => {
      await owner.sendTransaction({
        from: owner.address,
        to: merkleDistributor.address,
        value: utils.parseEther("100"),
      });

      await erc20Token.transfer(
        merkleDistributor.address,
        utils.parseEther("100")
      );
    });

    it("it reverts if msg.sender is not owner", async () => {
      await expect(
        merkleDistributor
          .connect(setter)
          .recoverToken(ETH, utils.parseEther("1"))
      ).revertedWith("Ownable: caller is not the owner");
    });

    it("recover ETH", async () => {
      const ownerBalanceBefore = await owner.getBalance();

      const amount = utils.parseEther("1");
      const tx = await merkleDistributor
        .connect(owner)
        .recoverToken(ETH, amount);

      const receipt = await tx.wait(1);

      const fee = receipt.gasUsed.mul(receipt.effectiveGasPrice);

      expect(
        await waffle.provider.getBalance(merkleDistributor.address)
      ).to.be.equal(utils.parseEther("99"));

      expect(await owner.getBalance()).to.be.equal(
        ownerBalanceBefore.add(amount).sub(fee)
      );
    });

    it("recover ERC20 token", async () => {
      const ownerBalanceBefore = await erc20Token.balanceOf(owner.address);

      const amount = utils.parseEther("1");
      await merkleDistributor
        .connect(owner)
        .recoverToken(erc20Token.address, amount);

      expect(await erc20Token.balanceOf(merkleDistributor.address)).to.be.equal(
        utils.parseEther("99")
      );

      expect(await erc20Token.balanceOf(owner.address)).to.be.equal(
        ownerBalanceBefore.add(amount)
      );
    });
  });

  const getMerkleTree = (infos: any[]): MerkleTree => {
    const leaves = infos.map((info) =>
      keccak256(
        utils.defaultAbiCoder.encode(
          ["address", "address", "uint256"],
          [info.user, info.token, info.allocation]
        )
      )
    );

    const merkleTree = new MerkleTree(leaves, keccak256, {
      sortPairs: true,
    });

    return merkleTree;
  };
});
