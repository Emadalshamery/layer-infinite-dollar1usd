// test/Dollar1usd.test.ts
import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";
import { Dollar1usd } from "../typechain-types";

describe("Dollar1usd Contract", function () {
  let usd1: Dollar1usd;
  let admin: Signer;
  let relayer: Signer;
  let user: Signer;

  beforeEach(async function () {
    [admin, relayer, user] = await ethers.getSigners();
    const USD1Factory = await ethers.getContractFactory("Dollar1usd");
    usd1 = (await USD1Factory.deploy(await relayer.getAddress())) as Dollar1usd;
    await usd1.waitForDeployment();
  });

  it("Should have correct name and symbol", async function () {
    expect(await usd1.name()).to.equal("Dollar1usd");
    expect(await usd1.symbol()).to.equal("USD1");
  });

  it("Should mint tokens correctly", async function () {
    const amount = ethers.parseEther("1000");
    const userAddress = await user.getAddress();
    await usd1.connect(relayer).mint(userAddress, amount);
    expect(await usd1.balanceOf(userAddress)).to.equal(amount);
  });

  it("Should enforce max supply limit", async function () {
    const maxSupply = await usd1.MAX_SUPPLY();
    const userAddress = await user.getAddress();
    await expect(
      usd1.connect(relayer).mint(userAddress, maxSupply + 1n)
    ).to.be.revertedWith("USD1: max supply exceeded");
  });

  it("Should apply fee on relayer transfers", async function () {
    const amount = ethers.parseEther("100");
    const userAddress = await user.getAddress();
    const relayerAddress = await relayer.getAddress();

    await usd1.connect(relayer).mint(relayerAddress, amount);
    await usd1.connect(relayer).bridgeTransfer(userAddress, amount);
    
    const fee = (amount * 5n) / 10000n;
    expect(await usd1.balanceOf(userAddress)).to.equal(amount - fee);
    expect(await usd1.balanceOf(await usd1.getAddress())).to.equal(fee);
  });

  it("Should not allow non-relayer to mint", async function () {
    const amount = ethers.parseEther("100");
    const userAddress = await user.getAddress();
    await expect(
      usd1.connect(user).mint(userAddress, amount)
    ).to.be.reverted;
  });
});
