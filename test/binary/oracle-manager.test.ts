import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { utils } from "ethers";
import { ethers } from "hardhat";
import { Oracle, OracleManager } from "../../typechain-types";

describe("Binary Option Trading - Oracle Manager", () => {
	let owner: SignerWithAddress;
	let user1: SignerWithAddress;

	let oracle1: Oracle;
	let oracle2: Oracle;
	let oracleManager: OracleManager;

	const time = 12345;
	const price = utils.parseEther("1");

	before(async () => {
		[owner, user1] = await ethers.getSigners();
	})

	beforeEach(async () => {
		const OracleFactory = await ethers.getContractFactory("Oracle");
		oracle1 = await OracleFactory.deploy();
		await oracle1.deployed();
		oracle2 = await OracleFactory.deploy();
		await oracle2.deployed();

		await oracle1.setWriter(owner.address, true);
		await oracle2.setWriter(owner.address, true);

		await oracle1.writeBatchPrices(
			[0, 1, 2],
			[time, time + 1, time + 2],
			[price, price, price]
		)
		await oracle2.writeBatchPrices(
			[0, 1, 2],
			[time, time + 1, time + 2],
			[price, price, price]
		)

		const OracleManagerFactory = await ethers.getContractFactory("OracleManager");
		oracleManager = await OracleManagerFactory.deploy();
		await oracleManager.deployed();
	})

	describe("Add Oracle", () => {
		it("should permit adding oracle to the owner", async () => {
			await expect(
				oracleManager.connect(user1).addOracle(0, oracle1.address)
			).to.be.revertedWith("Ownable: caller is not the owner");

			await expect(
				oracleManager.addOracle(0, oracle1.address)
			).to.be.emit(oracleManager, "OracleAdded").withArgs(0, oracle1.address);

			expect(await oracleManager.oracles(0)).to.be.equal(oracle1.address);
		})
		it("should validate oracle address", async () => {
			await oracleManager.addOracle(0, oracle1.address);

			await expect(
				oracleManager.addOracle(0, oracle2.address)
			).to.be.revertedWith("ORACLE_ALREADY_ADDED");
			await expect(
				oracleManager.addOracle(1, ethers.constants.AddressZero)
			).to.be.revertedWith("ZERO_ADDRESS");

			await oracleManager.addOracle(1, oracle2.address);
			expect(await oracleManager.oracles(1)).to.be.equal(oracle2.address);
		})
	})
	describe("Get Price", () => {
		beforeEach(async () => {
			await oracleManager.addOracle(0, oracle1.address);
			await oracleManager.addOracle(1, oracle2.address);
		})
		it("should return oracle price by market id", async () => {
			const round = await oracleManager.getPrice(0, 2);
			expect(round.timestamp).to.be.equal(time + 2);
			expect(round.price).to.be.equal(price);
		})
		it("should revert when getting price by invalid round id", async () => {
			await expect(
				oracleManager.getPrice(0, 5)
			).to.be.reverted;
		})
		it("should revert when getting price from invalid market", async () => {
			await expect(
				oracleManager.getPrice(4, 5)
			).to.be.reverted;
		})
	})
})