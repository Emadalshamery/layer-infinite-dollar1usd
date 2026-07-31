import { ethers } from "hardhat";

async function main() {
  console.log("🚀 Deploying Layer Infinite Protocol...");
  
  const [deployer] = await ethers.getSigners();
  console.log(`📡 Deploying with account: ${deployer.address}`);

  // 1. Deploy Dollar1usd
  console.log("\n📝 Deploying Dollar1usd...");
  const USD1Factory = await ethers.getContractFactory("Dollar1usd");
  const usd1 = await USD1Factory.deploy(deployer.address);
  await usd1.waitForDeployment();
  const usd1Address = await usd1.getAddress();
  console.log(`✅ USD1 deployed at: ${usd1Address}`);

  // 2. Deploy SovereignRelayer
  console.log("\n📝 Deploying SovereignRelayer...");
  const RelayerFactory = await ethers.getContractFactory("SovereignRelayer");
  const relayer = await RelayerFactory.deploy();
  await relayer.waitForDeployment();
  const relayerAddress = await relayer.getAddress();
  console.log(`✅ Relayer deployed at: ${relayerAddress}`);

  // 3. Deploy InfiniteDelegationEngine
  console.log("\n📝 Deploying InfiniteDelegationEngine...");
  const IDEFactory = await ethers.getContractFactory("InfiniteDelegationEngine");
  const ide = await IDEFactory.deploy();
  await ide.waitForDeployment();
  const ideAddress = await ide.getAddress();
  console.log(`✅ IDE deployed at: ${ideAddress}`);

  // 4. Grant roles
  console.log("\n🔑 Granting roles...");
  await usd1.grantRole(await usd1.RELAYER_ROLE(), relayerAddress);
  await usd1.grantRole(await usd1.MINTER_ROLE(), relayerAddress);
  console.log(`✅ Roles granted to relayer`);

  // 5. Deployment summary
  console.log("\n📋 Deployment Summary:");
  console.log("=".repeat(50));
  console.log(`Network: ${await ethers.provider.getNetwork()}`);
  console.log(`USD1: ${usd1Address}`);
  console.log(`Relayer: ${relayerAddress}`);
  console.log(`IDE: ${ideAddress}`);
  console.log(`Admin: ${deployer.address}`);
  console.log("=".repeat(50));

  // 6. Save deployment info
  const fs = require("fs");
  const deploymentInfo = {
    network: (await ethers.provider.getNetwork()).name,
    chainId: (await ethers.provider.getNetwork()).chainId,
    contracts: {
      USD1: usd1Address,
      Relayer: relayerAddress,
      IDE: ideAddress,
    },
    admin: deployer.address,
    timestamp: new Date().toISOString(),
  };
  
  fs.writeFileSync(
    "deployment.json",
    JSON.stringify(deploymentInfo, null, 2)
  );
  console.log("\n💾 Deployment info saved to deployment.json");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
