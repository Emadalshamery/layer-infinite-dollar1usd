import { ethers, run } from "hardhat";

async function main() {
  console.log("🚀 Starting comprehensive deployment process for Layer Infinite & Dollar1usd...");

  // --- 1. نشر محرك التفويض الذكي ---
  const InfiniteDelegationEngine = await ethers.getContractFactory("InfiniteDelegationEngine");
  console.log("⏳ Deploying InfiniteDelegationEngine...");
  const ide = await InfiniteDelegationEngine.deploy();
  await ide.waitForDeployment();
  const ideAddress = await ide.getAddress();
  console.log(`✅ InfiniteDelegationEngine deployed to: ${ideAddress}`);

  // --- 2. نشر عقد التوكن المستقر (1USD) ---
  const Dollar1usdToken = await ethers.getContractFactory("Dollar1usdToken");
  console.log("⏳ Deploying Dollar1usdToken...");
  const token = await Dollar1usdToken.deploy();
  await token.waitForDeployment();
  const tokenAddress = await token.getAddress();
  console.log(`✅ Dollar1usdToken deployed to: ${tokenAddress}`);

  // --- 3. ربط وتفويض محرك الـ IDE داخل عقد التوكن كـ Authority ---
  console.log("⏳ Registering IDE into Dollar1usd Token Authority Cluster...");
  const tx = await token.updateAuthorityStatus(ideAddress, true);
  await tx.wait(1);
  console.log("🔒 IDE successfully authorized to secure token operations!");

  // --- 4. التحقق التلقائي على المستكشف (Verification) ---
  const network = await ethers.provider.getNetwork();
  const localChainIds = [31337, 1337];

  if (!localChainIds.includes(Number(network.chainId))) {
    console.log("⏳ Waiting for network confirmations before verification...");
    await token.deploymentTransaction()?.wait(5);

    // التحقق من العقد الأول
    try {
      await run("verify:verify", { address: ideAddress, constructorArguments: [] });
    } catch (e) { console.log("IDE Verification note:", e.message); }

    // التحقق من العقد الثاني
    try {
      await run("verify:verify", { address: tokenAddress, constructorArguments: [] });
    } catch (e) { console.log("Token Verification note:", e.message); }
    
    console.log("🎉 All network verifications completed!");
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("🚨 Deployment process failed:", error);
    process.exit(1);
  });
