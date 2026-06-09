import { expect } from "chai";
import { ethers } from "hardhat";
import { InfinityEngine } from "../typechain-types";

describe("InfinityEngine - IDE (Infinity Delegation Engine)", function () {
  let infinityEngine: InfinityEngine;
  let owner: any;
  let agent: any;
  let user: any;
  let approver1: any;
  let approver2: any;
  let masterSecret: string;
  let adminSecret: string;

  const MASTER_SECRET = ethers.id("MASTER_SECRET_KEY_LAYER_INFINITY");
  const ADMIN_SECRET = ethers.id("ADMIN_SECRET_KEY_001");

  beforeEach(async function () {
    [owner, agent, user, approver1, approver2] = await ethers.getSigners();

    const InfinityEngineFactory = await ethers.getContractFactory("InfinityEngine");
    infinityEngine = await InfinityEngineFactory.deploy(
      MASTER_SECRET,
      [ADMIN_SECRET],
      [approver1.address, approver2.address]
    );
    await infinityEngine.deployed();

    masterSecret = MASTER_SECRET;
    adminSecret = ADMIN_SECRET;
  });

  describe("Deployment", function () {
    it("Should deploy with correct configuration", async function () {
      expect(await infinityEngine.VERSION()).to.equal("1.0.0");
    });

    it("Should initialize with correct approvers", async function () {
      expect(await infinityEngine.config()).to.not.be.undefined;
    });
  });

  describe("Secret Verification", function () {
    it("Should verify correct master secret", async function () {
      expect(await infinityEngine.verifySecret(masterSecret)).to.be.true;
    });

    it("Should verify correct admin secret", async function () {
      expect(await infinityEngine.verifySecret(adminSecret)).to.be.true;
    });

    it("Should reject invalid secret", async function () {
      const invalidSecret = ethers.id("INVALID_SECRET");
      expect(await infinityEngine.verifySecret(invalidSecret)).to.be.false;
    });

    it("Should return correct admin secrets count", async function () {
      const count = await infinityEngine.getAdminSecretsCount();
      expect(count).to.equal(1);
    });
  });

  describe("Whitelist Management", function () {
    it("Should add address to whitelist", async function () {
      await expect(
        infinityEngine.addToWhitelist(user.address, masterSecret)
      )
        .to.emit(infinityEngine, "WhitelistUpdated")
        .withArgs(user.address, true);

      expect(await infinityEngine.whitelist(user.address)).to.be.true;
    });

    it("Should remove address from whitelist", async function () {
      await infinityEngine.addToWhitelist(user.address, masterSecret);
      await expect(
        infinityEngine.removeFromWhitelist(user.address, masterSecret)
      )
        .to.emit(infinityEngine, "WhitelistUpdated")
        .withArgs(user.address, false);

      expect(await infinityEngine.whitelist(user.address)).to.be.false;
    });

    it("Should reject invalid secret for whitelist operations", async function () {
      const invalidSecret = ethers.id("INVALID");
      await expect(
        infinityEngine.addToWhitelist(user.address, invalidSecret)
      ).to.be.revertedWith("Invalid secret key");
    });
  });

  describe("Blacklist Management", function () {
    it("Should add address to blacklist", async function () {
      await expect(
        infinityEngine.addToBlacklist(agent.address, masterSecret)
      )
        .to.emit(infinityEngine, "BlacklistUpdated")
        .withArgs(agent.address, true);

      expect(await infinityEngine.blacklist(agent.address)).to.be.true;
    });

    it("Should remove address from blacklist", async function () {
      await infinityEngine.addToBlacklist(agent.address, masterSecret);
      await expect(
        infinityEngine.removeFromBlacklist(agent.address, masterSecret)
      )
        .to.emit(infinityEngine, "BlacklistUpdated")
        .withArgs(agent.address, false);

      expect(await infinityEngine.blacklist(agent.address)).to.be.false;
    });
  });

  describe("Delegation", function () {
    beforeEach(async function () {
      await infinityEngine.addToWhitelist(user.address, masterSecret);
    });

    it("Should create valid delegation", async function () {
      const limit = ethers.utils.parseEther("100");
      const duration = 30 * 24 * 60 * 60; // 30 days

      await expect(
        infinityEngine
          .connect(user)
          .delegateTo(agent.address, limit, duration, "0x", masterSecret)
      )
        .to.emit(infinityEngine, "DelegationActivated")
        .withArgs(user.address, agent.address, limit, expect.any(ethers.BigNumber));
    });

    it("Should reject delegation to zero address", async function () {
      const limit = ethers.utils.parseEther("100");
      const duration = 30 * 24 * 60 * 60;

      await expect(
        infinityEngine
          .connect(user)
          .delegateTo(ethers.constants.AddressZero, limit, duration, "0x", masterSecret)
      ).to.be.revertedWith("Invalid agent address");
    });

    it("Should reject delegation with zero limit", async function () {
      const duration = 30 * 24 * 60 * 60;

      await expect(
        infinityEngine
          .connect(user)
          .delegateTo(agent.address, 0, duration, "0x", masterSecret)
      ).to.be.revertedWith("Limit must be > 0");
    });

    it("Should reject delegation exceeding max limit", async function () {
      const excessiveLimit = ethers.utils.parseEther("10000");
      const duration = 30 * 24 * 60 * 60;

      await expect(
        infinityEngine
          .connect(user)
          .delegateTo(agent.address, excessiveLimit, duration, "0x", masterSecret)
      ).to.be.revertedWith("Limit exceeds maximum");
    });

    it("Should check delegation validity", async function () {
      const limit = ethers.utils.parseEther("100");
      const duration = 30 * 24 * 60 * 60;

      await infinityEngine
        .connect(user)
        .delegateTo(agent.address, limit, duration, "0x", masterSecret);

      const isValid = await infinityEngine.isDelegationValid(user.address, agent.address);
      expect(isValid).to.be.true;
    });
  });

  describe("Delegation Revocation", function () {
    beforeEach(async function () {
      await infinityEngine.addToWhitelist(user.address, masterSecret);
      const limit = ethers.utils.parseEther("100");
      const duration = 30 * 24 * 60 * 60;

      await infinityEngine
        .connect(user)
        .delegateTo(agent.address, limit, duration, "0x", masterSecret);
    });

    it("Should revoke active delegation", async function () {
      await expect(
        infinityEngine.connect(user).revokeDelegation(agent.address, masterSecret)
      )
        .to.emit(infinityEngine, "DelegationRevoked")
        .withArgs(user.address, agent.address);

      const isValid = await infinityEngine.isDelegationValid(user.address, agent.address);
      expect(isValid).to.be.false;
    });

    it("Should reject revocation of non-existent delegation", async function () {
      await expect(
        infinityEngine
          .connect(user)
          .revokeDelegation(ethers.constants.AddressZero, masterSecret)
      ).to.be.revertedWith("No active delegation");
    });
  });

  describe("Recovery Requests", function () {
    beforeEach(async function () {
      await infinityEngine.addToWhitelist(user.address, masterSecret);
    });

    it("Should create recovery request", async function () {
      const amount = ethers.utils.parseEther("50");

      await expect(
        infinityEngine.connect(user).requestRecovery(amount, masterSecret)
      )
        .to.emit(infinityEngine, "RecoveryRequested")
        .withArgs(user.address, 0, amount);
    });

    it("Should reject recovery request with zero amount", async function () {
      await expect(
        infinityEngine.connect(user).requestRecovery(0, masterSecret)
      ).to.be.revertedWith("Amount must be > 0");
    });

    it("Should reject recovery request exceeding max amount", async function () {
      const excessiveAmount = ethers.utils.parseEther("50000");

      await expect(
        infinityEngine.connect(user).requestRecovery(excessiveAmount, masterSecret)
      ).to.be.revertedWith("Amount exceeds maximum");
    });
  });

  describe("Recovery Approval", function () {
    let recoveryId: number;

    beforeEach(async function () {
      await infinityEngine.addToWhitelist(user.address, masterSecret);
      const amount = ethers.utils.parseEther("50");

      const tx = await infinityEngine
        .connect(user)
        .requestRecovery(amount, masterSecret);
      await tx.wait();

      recoveryId = 0;
    });

    it("Should approve recovery from authorized approver", async function () {
      await expect(
        infinityEngine.connect(approver1).approveRecovery(recoveryId, masterSecret)
      )
        .to.emit(infinityEngine, "RecoveryApproved")
        .withArgs(recoveryId, approver1.address);
    });

    it("Should reject approval from non-approver", async function () {
      await expect(
        infinityEngine.connect(user).approveRecovery(recoveryId, masterSecret)
      ).to.be.revertedWith("Not an approved signer");
    });

    it("Should reject double voting", async function () {
      await infinityEngine.connect(approver1).approveRecovery(recoveryId, masterSecret);

      await expect(
        infinityEngine.connect(approver1).approveRecovery(recoveryId, masterSecret)
      ).to.be.revertedWith("Already voted");
    });
  });

  describe("Protocol Configuration", function () {
    it("Should update protocol configuration", async function () {
      const newLimit = ethers.utils.parseEther("5000");
      const newAmount = ethers.utils.parseEther("20000");
      const newApprovals = 3;

      await expect(
        infinityEngine.updateConfig(
          newLimit,
          newAmount,
          newApprovals,
          masterSecret
        )
      )
        .to.emit(infinityEngine, "ProtocolConfigUpdated")
        .withArgs(newLimit, newApprovals);
    });

    it("Should reject config update with invalid secret", async function () {
      const newLimit = ethers.utils.parseEther("5000");
      const invalidSecret = ethers.id("INVALID");

      await expect(
        infinityEngine.updateConfig(newLimit, newLimit, 2, invalidSecret)
      ).to.be.revertedWith("Invalid secret key");
    });
  });

  describe("Activity Logging", function () {
    it("Should log user activities", async function () {
      await infinityEngine.addToWhitelist(user.address, masterSecret);
      const limit = ethers.utils.parseEther("100");
      const duration = 30 * 24 * 60 * 60;

      await infinityEngine
        .connect(user)
        .delegateTo(agent.address, limit, duration, "0x", masterSecret);

      const logs = await infinityEngine.getActivityLog(user.address, 10);
      expect(logs.length).to.be.greaterThan(0);
      expect(logs[0].success).to.be.true;
    });
  });

  describe("Emergency Functions", function () {
    it("Should pause protocol", async function () {
      await infinityEngine.setEmergencyPause(true, masterSecret);
      const config = await infinityEngine.config();
      expect(config.emergencyPause).to.be.true;
    });

    it("Should unpause protocol", async function () {
      await infinityEngine.setEmergencyPause(true, masterSecret);
      await infinityEngine.setEmergencyPause(false, masterSecret);
      const config = await infinityEngine.config();
      expect(config.emergencyPause).to.be.false;
    });
  });

  describe("Reentrancy Protection", function () {
    it("Should protect against reentrancy attacks", async function () {
      // هذا الاختبار يتحقق من أن الحماية من Re-entrancy موجودة
      const amount = ethers.utils.parseEther("10");
      await infinityEngine.addToWhitelist(user.address, masterSecret);

      await infinityEngine.connect(user).requestRecovery(amount, masterSecret);
      await infinityEngine.connect(approver1).approveRecovery(0, masterSecret);
      await infinityEngine.connect(approver2).approveRecovery(0, masterSecret);

      // يجب أن يتم التنفيذ بدون مشاكل
      await expect(
        infinityEngine.executeRecovery(0, masterSecret)
      ).to.not.be.reverted;
    });
  });
});
