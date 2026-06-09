import { expect } from "chai";
import { ethers } from "hardhat";
import { UnifiedIdentitySystem } from "../typechain-types";

describe("UnifiedIdentitySystem - UIS (Unified Identity)", function () {
  let uis: UnifiedIdentitySystem;
  let owner: any;
  let user: any;
  let user2: any;
  let verifier1: any;
  let verifier2: any;
  let identitySecret: string;

  const IDENTITY_SECRET = ethers.id("IDENTITY_SECRET_KEY_LAYER_INFINITY");

  beforeEach(async function () {
    [owner, user, user2, verifier1, verifier2] = await ethers.getSigners();

    const UISFactory = await ethers.getContractFactory("UnifiedIdentitySystem");
    uis = await UISFactory.deploy(
      IDENTITY_SECRET,
      [verifier1.address, verifier2.address]
    );
    await uis.deployed();

    identitySecret = IDENTITY_SECRET;
  });

  describe("Deployment", function () {
    it("Should deploy with correct version", async function () {
      expect(await uis.VERSION()).to.equal("1.0.0");
    });
  });

  describe("Identity Creation", function () {
    it("Should create a new identity", async function () {
      const username = "alice";
      const profileHash = ethers.id("profile_data");

      const tx = await uis
        .connect(user)
        .createIdentity(username, profileHash, false, identitySecret);

      await expect(tx)
        .to.emit(uis, "IdentityCreated")
        .withArgs(expect.any(String), user.address, username);
    });

    it("Should reject empty username", async function () {
      const profileHash = ethers.id("profile_data");

      await expect(
        uis.connect(user).createIdentity("", profileHash, false, identitySecret)
      ).to.be.revertedWith("Username required");
    });

    it("Should reject duplicate identity creation", async function () {
      const username = "alice";
      const profileHash = ethers.id("profile_data");

      await uis
        .connect(user)
        .createIdentity(username, profileHash, false, identitySecret);

      await expect(
        uis.connect(user).createIdentity(username, profileHash, false, identitySecret)
      ).to.be.revertedWith("Identity already exists");
    });

    it("Should reject invalid secret", async function () {
      const username = "alice";
      const profileHash = ethers.id("profile_data");
      const invalidSecret = ethers.id("INVALID");

      await expect(
        uis.connect(user).createIdentity(username, profileHash, false, invalidSecret)
      ).to.be.revertedWith("Invalid secret");
    });
  });

  describe("Address Linking", function () {
    let identityId: string;

    beforeEach(async function () {
      const username = "alice";
      const profileHash = ethers.id("profile_data");

      const tx = await uis
        .connect(user)
        .createIdentity(username, profileHash, false, identitySecret);
      const receipt = await tx.wait();

      const event = receipt.events?.find(
        (e: any) => e.event === "IdentityCreated"
      );
      identityId = event?.args[0];
    });

    it("Should link a new address with valid signature", async function () {
      const messageHash = ethers.utils.solidityKeccak256(
        ["bytes32", "address", "uint256"],
        [identityId, user2.address, Math.floor(Date.now() / 1000)]
      );

      const signature = await user2.signMessage(
        ethers.utils.arrayify(messageHash)
      );

      await expect(
        uis
          .connect(user)
          .linkAddress(identityId, user2.address, signature, identitySecret)
      ).to.not.be.reverted;
    });

    it("Should prevent non-owner from linking address", async function () {
      const messageHash = ethers.utils.solidityKeccak256(
        ["bytes32", "address", "uint256"],
        [identityId, user2.address, Math.floor(Date.now() / 1000)]
      );

      const signature = await user2.signMessage(
        ethers.utils.arrayify(messageHash)
      );

      await expect(
        uis
          .connect(verifier1)
          .linkAddress(identityId, user2.address, signature, identitySecret)
      ).to.be.revertedWith("Not identity owner");
    });
  });

  describe("Profile Management", function () {
    let identityId: string;

    beforeEach(async function () {
      const username = "alice";
      const profileHash = ethers.id("profile_data");

      const tx = await uis
        .connect(user)
        .createIdentity(username, profileHash, false, identitySecret);
      const receipt = await tx.wait();

      const event = receipt.events?.find(
        (e: any) => e.event === "IdentityCreated"
      );
      identityId = event?.args[0];
    });

    it("Should update profile", async function () {
      const displayName = "Alice Smith";
      const avatarHash = ethers.id("avatar");
      const bio = "Software engineer and Web3 enthusiast";

      await expect(
        uis
          .connect(user)
          .updateProfile(identityId, displayName, avatarHash, bio, identitySecret)
      )
        .to.emit(uis, "ProfileUpdated")
        .withArgs(identityId, displayName);
    });

    it("Should retrieve profile", async function () {
      const displayName = "Alice Smith";
      const avatarHash = ethers.id("avatar");
      const bio = "Software engineer";

      await uis
        .connect(user)
        .updateProfile(identityId, displayName, avatarHash, bio, identitySecret);

      const { 0: name, 1: avatar, 2: userBio } = await uis.getProfile(
        identityId
      );

      expect(name).to.equal(displayName);
    });
  });

  describe("Identity Verification", function () {
    let identityId: string;

    beforeEach(async function () {
      const username = "alice";
      const profileHash = ethers.id("profile_data");

      const tx = await uis
        .connect(user)
        .createIdentity(username, profileHash, false, identitySecret);
      const receipt = await tx.wait();

      const event = receipt.events?.find(
        (e: any) => e.event === "IdentityCreated"
      );
      identityId = event?.args[0];
    });

    it("Should verify identity as verifier", async function () {
      await expect(
        uis.connect(verifier1).verifyIdentity(identityId, identitySecret)
      )
        .to.emit(uis, "IdentityVerified")
        .withArgs(identityId, verifier1.address);
    });

    it("Should reject verification from non-verifier", async function () {
      await expect(
        uis.connect(user).verifyIdentity(identityId, identitySecret)
      ).to.be.revertedWith("Not a verifier");
    });
  });

  describe("Privacy Mode", function () {
    let identityId: string;

    beforeEach(async function () {
      const username = "alice";
      const profileHash = ethers.id("profile_data");

      const tx = await uis
        .connect(user)
        .createIdentity(username, profileHash, false, identitySecret);
      const receipt = await tx.wait();

      const event = receipt.events?.find(
        (e: any) => e.event === "IdentityCreated"
      );
      identityId = event?.args[0];
    });

    it("Should toggle privacy mode", async function () {
      await expect(
        uis
          .connect(user)
          .togglePrivacyMode(identityId, identitySecret)
      )
        .to.emit(uis, "PrivacyModeToggled")
        .withArgs(identityId, true);
    });
  });

  describe("Asset Tracking", function () {
    let identityId: string;

    beforeEach(async function () {
      const username = "alice";
      const profileHash = ethers.id("profile_data");

      const tx = await uis
        .connect(user)
        .createIdentity(username, profileHash, false, identitySecret);
      const receipt = await tx.wait();

      const event = receipt.events?.find(
        (e: any) => e.event === "IdentityCreated"
      );
      identityId = event?.args[0];
    });

    it("Should record asset snapshot", async function () {
      const balance = ethers.utils.parseEther("100");

      await expect(
        uis
          .connect(user)
          .recordAssetSnapshot(identityId, "ethereum", balance, identitySecret)
      )
        .to.emit(uis, "AssetSnapshotRecorded")
        .withArgs(identityId, "ethereum", balance);
    });

    it("Should retrieve asset snapshot", async function () {
      const balance = ethers.utils.parseEther("100");

      await uis
        .connect(user)
        .recordAssetSnapshot(identityId, "ethereum", balance, identitySecret);

      const { 0: retrievedBalance } = await uis.getAssetSnapshot(
        identityId,
        "ethereum"
      );

      expect(retrievedBalance).to.equal(balance);
    });
  });
});
