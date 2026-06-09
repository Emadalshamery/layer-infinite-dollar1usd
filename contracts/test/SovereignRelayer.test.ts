import { expect } from "chai";
import { ethers } from "hardhat";
import { SovereignRelayer } from "../typechain-types";

describe("SovereignRelayer - Relay Network", function () {
  let relayer: SovereignRelayer;
  let owner: any;
  let relayerNode: any;
  let user: any;
  let treasury: any;
  let relayerSecret: string;

  const RELAYER_SECRET = ethers.id("RELAYER_SECRET_KEY_LAYER_INFINITY");

  beforeEach(async function () {
    [owner, relayerNode, user, treasury] = await ethers.getSigners();

    const RelayerFactory = await ethers.getContractFactory("SovereignRelayer");
    relayer = await RelayerFactory.deploy(RELAYER_SECRET, treasury.address);
    await relayer.deployed();

    relayerSecret = RELAYER_SECRET;
  });

  describe("Deployment", function () {
    it("Should deploy with correct version", async function () {
      expect(await relayer.VERSION()).to.equal("1.0.0");
    });
  });

  describe("Relayer Node Registration", function () {
    it("Should register a relayer node", async function () {
      const nodeId = "node-001";
      const stake = ethers.utils.parseEther("10");

      await expect(
        relayer.connect(relayerNode).registerRelayerNode(nodeId, relayerSecret, {
          value: stake,
        })
      )
        .to.emit(relayer, "RelayerNodeRegistered")
        .withArgs(relayerNode.address, nodeId);
    });

    it("Should reject registration without stake", async function () {
      const nodeId = "node-001";

      await expect(
        relayer
          .connect(relayerNode)
          .registerRelayerNode(nodeId, relayerSecret, { value: 0 })
      ).to.be.revertedWith("Stake required");
    });

    it("Should reject duplicate registration", async function () {
      const nodeId = "node-001";
      const stake = ethers.utils.parseEther("10");

      await relayer
        .connect(relayerNode)
        .registerRelayerNode(nodeId, relayerSecret, { value: stake });

      await expect(
        relayer
          .connect(relayerNode)
          .registerRelayerNode(nodeId, relayerSecret, { value: stake })
      ).to.be.revertedWith("Already registered");
    });
  });

  describe("Transaction Submission", function () {
    it("Should submit transaction for relay", async function () {
      const target = user.address;
      const value = ethers.utils.parseEther("1");
      const data = "0x";
      const gasLimit = 21000;
      const signature = "0x";

      const messageHash = ethers.utils.solidityKeccak256(
        ["address", "address", "uint256", "bytes", "uint256", "uint256"],
        [user.address, target, value, data, 0, gasLimit]
      );

      const sig = await user.signMessage(ethers.utils.arrayify(messageHash));

      await expect(
        relayer.connect(user).submitTransaction(
          target,
          value,
          data,
          gasLimit,
          sig,
          relayerSecret,
          { value: value }
        )
      )
        .to.emit(relayer, "TransactionSubmitted")
        .withArgs(0, user.address, target, value);
    });

    it("Should reject transaction with invalid target", async function () {
      const value = ethers.utils.parseEther("1");
      const data = "0x";
      const gasLimit = 21000;
      const signature = "0x";

      await expect(
        relayer.connect(user).submitTransaction(
          ethers.constants.AddressZero,
          value,
          data,
          gasLimit,
          signature,
          relayerSecret,
          { value: value }
        )
      ).to.be.revertedWith("Invalid target");
    });
  });

  describe("MEV Protection Configuration", function () {
    it("Should update MEV configuration", async function () {
      await relayer.updateMEVConfig(
        true,
        true,
        true,
        relayerSecret
      );

      const config = await relayer.getMEVConfig();
      expect(config[0]).to.be.true;
      expect(config[1]).to.be.true;
      expect(config[2]).to.be.true;
    });

    it("Should reject MEV config update from non-owner", async function () {
      await expect(
        relayer
          .connect(relayerNode)
          .updateMEVConfig(true, true, true, relayerSecret)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Fee Management", function () {
    it("Should collect fees", async function () {
      // Submit a transaction
      const target = user.address;
      const value = ethers.utils.parseEther("100");
      const data = "0x";
      const gasLimit = 21000;

      const messageHash = ethers.utils.solidityKeccak256(
        ["address", "address", "uint256", "bytes", "uint256", "uint256"],
        [user.address, target, value, data, 0, gasLimit]
      );

      const sig = await user.signMessage(ethers.utils.arrayify(messageHash));

      // Register relayer node
      const nodeId = "node-001";
      const stake = ethers.utils.parseEther("10");
      await relayer
        .connect(relayerNode)
        .registerRelayerNode(nodeId, relayerSecret, { value: stake });

      // Submit transaction
      await relayer.connect(user).submitTransaction(
        target,
        value,
        data,
        gasLimit,
        sig,
        relayerSecret,
        { value: value }
      );
    });
  });

  describe("Emergency Functions", function () {
    it("Should pause the relayer", async function () {
      await relayer.pause(relayerSecret);

      const target = user.address;
      const value = ethers.utils.parseEther("1");
      const data = "0x";
      const gasLimit = 21000;
      const signature = "0x";

      await expect(
        relayer.connect(user).submitTransaction(
          target,
          value,
          data,
          gasLimit,
          signature,
          relayerSecret
        )
      ).to.be.revertedWith("Pausable: paused");
    });

    it("Should unpause the relayer", async function () {
      await relayer.pause(relayerSecret);
      await relayer.unpause(relayerSecret);

      // Should not be paused anymore
      const target = user.address;
      const value = ethers.utils.parseEther("1");
      const data = "0x";
      const gasLimit = 21000;

      const messageHash = ethers.utils.solidityKeccak256(
        ["address", "address", "uint256", "bytes", "uint256", "uint256"],
        [user.address, target, value, data, 0, gasLimit]
      );

      const sig = await user.signMessage(ethers.utils.arrayify(messageHash));

      await expect(
        relayer.connect(user).submitTransaction(
          target,
          value,
          data,
          gasLimit,
          sig,
          relayerSecret,
          { value: value }
        )
      ).to.not.be.reverted;
    });
  });
});
