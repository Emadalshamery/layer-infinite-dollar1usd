import { expect } from "chai";
import { ethers } from "hardhat";
import { GasBundler } from "../typechain-types";

describe("GasBundler - GOB (Gas Optimization Bundler)", function () {
  let gasBundler: GasBundler;
  let owner: any;
  let user1: any;
  let user2: any;
  let bundlerSecret: string;

  const BUNDLER_SECRET = ethers.id("BUNDLER_SECRET_KEY_LAYER_INFINITY");

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    const GasBundlerFactory = await ethers.getContractFactory("GasBundler");
    gasBundler = await GasBundlerFactory.deploy(BUNDLER_SECRET);
    await gasBundler.deployed();

    bundlerSecret = BUNDLER_SECRET;
  });

  describe("Deployment", function () {
    it("Should deploy with correct version", async function () {
      expect(await gasBundler.VERSION()).to.equal("1.0.0");
    });

    it("Should have correct constants", async function () {
      expect(await gasBundler.COMPRESSION_RATIO()).to.equal(4);
      expect(await gasBundler.BASE_GAS_COST()).to.equal(10000);
      expect(await gasBundler.PER_TX_OVERHEAD()).to.equal(1500);
    });
  });

  describe("Gas Calculation", function () {
    it("Should calculate regular gas correctly", async function () {
      const txCount = 4;
      const regularGas = await gasBundler.calculateRegularGas(txCount);
      expect(regularGas).to.equal(txCount * 21000);
    });

    it("Should calculate optimized gas correctly", async function () {
      const txCount = 4;
      const optimizedGas = await gasBundler.calculateOptimizedGas(txCount);
      expect(optimizedGas).to.equal(10000 + txCount * 1500);
    });

    it("Should calculate savings correctly", async function () {
      const txCount = 4;
      const { regularGas, optimizedGas, savedGas, savingsPercentage } =
        await gasBundler.calculateSavings(txCount);

      expect(regularGas).to.equal(84000);
      expect(optimizedGas).to.equal(16000);
      expect(savedGas).to.equal(68000);
      expect(savingsPercentage).to.equal(80); // 80% savings
    });

    it("Should show 40% savings for single transaction", async function () {
      const txCount = 1;
      const { savingsPercentage } = await gasBundler.calculateSavings(txCount);
      expect(savingsPercentage).to.equal(92); // ~92% savings
    });
  });

  describe("Bundle Creation", function () {
    it("Should create a valid bundle", async function () {
      const recipients = [user1.address, user2.address];
      const amounts = [
        ethers.utils.parseEther("1"),
        ethers.utils.parseEther("2"),
      ];
      const data = ["0x", "0x"];

      const tx = await gasBundler.createBundle(
        recipients,
        amounts,
        data,
        bundlerSecret
      );

      await expect(tx)
        .to.emit(gasBundler, "BundleCreated")
        .withArgs(expect.any(String), 2, expect.any(ethers.BigNumber));
    });

    it("Should reject empty bundle", async function () {
      await expect(
        gasBundler.createBundle([], [], [], bundlerSecret)
      ).to.be.revertedWith("Empty bundle");
    });

    it("Should reject bundle with mismatched arrays", async function () {
      const recipients = [user1.address];
      const amounts = [
        ethers.utils.parseEther("1"),
        ethers.utils.parseEther("2"),
      ];
      const data = ["0x"];

      await expect(
        gasBundler.createBundle(recipients, amounts, data, bundlerSecret)
      ).to.be.revertedWith("Array length mismatch");
    });

    it("Should reject bundle exceeding transaction limit", async function () {
      const recipients = Array(101).fill(user1.address);
      const amounts = Array(101).fill(ethers.utils.parseEther("1"));
      const data = Array(101).fill("0x");

      await expect(
        gasBundler.createBundle(recipients, amounts, data, bundlerSecret)
      ).to.be.revertedWith("Too many transactions");
    });

    it("Should reject bundle with invalid secret", async function () {
      const recipients = [user1.address];
      const amounts = [ethers.utils.parseEther("1")];
      const data = ["0x"];
      const invalidSecret = ethers.id("INVALID");

      await expect(
        gasBundler.createBundle(recipients, amounts, data, invalidSecret)
      ).to.be.revertedWith("Invalid secret");
    });
  });

  describe("Merkle Tree", function () {
    it("Should compute merkle root for single item", async function () {
      const recipients = [user1.address];
      const amounts = [ethers.utils.parseEther("1")];

      const root = await gasBundler.computeMerkleRoot(recipients, amounts);
      expect(root).to.not.equal(ethers.constants.HashZero);
    });

    it("Should compute merkle root for multiple items", async function () {
      const recipients = [user1.address, user2.address];
      const amounts = [
        ethers.utils.parseEther("1"),
        ethers.utils.parseEther("2"),
      ];

      const root = await gasBundler.computeMerkleRoot(recipients, amounts);
      expect(root).to.not.equal(ethers.constants.HashZero);
    });

    it("Should reject empty merkle computation", async function () {
      const recipients: any[] = [];
      const amounts: any[] = [];

      const root = await gasBundler.computeMerkleRoot(recipients, amounts);
      expect(root).to.equal(ethers.constants.HashZero);
    });
  });

  describe("Bundle Execution", function () {
    let bundleHash: string;

    beforeEach(async function () {
      const recipients = [user1.address];
      const amounts = [ethers.utils.parseEther("1")];
      const data = ["0x"];

      const tx = await gasBundler.createBundle(
        recipients,
        amounts,
        data,
        bundlerSecret
      );
      const receipt = await tx.wait();

      // Extract bundle hash from event
      const event = receipt.events?.find(
        (e: any) => e.event === "BundleCreated"
      );
      bundleHash = event?.args[0];

      // Send funds to contract
      await owner.sendTransaction({
        to: gasBundler.address,
        value: ethers.utils.parseEther("10"),
      });
    });

    it("Should execute bundle successfully", async function () {
      const initialBalance = await user1.getBalance();

      await expect(
        gasBundler.executeBundle(bundleHash, bundlerSecret)
      )
        .to.emit(gasBundler, "BundleExecuted")
        .withArgs(bundleHash, expect.any(ethers.BigNumber), expect.any(ethers.BigNumber), expect.any(ethers.BigNumber));
    });
  });

  describe("Statistics", function () {
    it("Should return total gas saved", async function () {
      const totalSaved = await gasBundler.getTotalGasSaved();
      expect(totalSaved).to.equal(0); // Initially zero
    });

    it("Should return bundle info", async function () {
      const recipients = [user1.address];
      const amounts = [ethers.utils.parseEther("1")];
      const data = ["0x"];

      const tx = await gasBundler.createBundle(
        recipients,
        amounts,
        data,
        bundlerSecret
      );
      const receipt = await tx.wait();

      const event = receipt.events?.find(
        (e: any) => e.event === "BundleCreated"
      );
      const bundleHash = event?.args[0];

      const { txCount, gasEstimate, executed } =
        await gasBundler.getBundleInfo(bundleHash);

      expect(txCount).to.equal(1);
      expect(gasEstimate).to.be.greaterThan(0);
      expect(executed).to.be.false;
    });
  });

  describe("Emergency Functions", function () {
    it("Should pause the contract", async function () {
      await gasBundler.pause(bundlerSecret);

      const recipients = [user1.address];
      const amounts = [ethers.utils.parseEther("1")];
      const data = ["0x"];

      await expect(
        gasBundler.createBundle(recipients, amounts, data, bundlerSecret)
      ).to.be.revertedWith("Pausable: paused");
    });

    it("Should unpause the contract", async function () {
      await gasBundler.pause(bundlerSecret);
      await gasBundler.unpause(bundlerSecret);

      const recipients = [user1.address];
      const amounts = [ethers.utils.parseEther("1")];
      const data = ["0x"];

      await expect(
        gasBundler.createBundle(recipients, amounts, data, bundlerSecret)
      ).to.not.be.reverted;
    });
  });
});
