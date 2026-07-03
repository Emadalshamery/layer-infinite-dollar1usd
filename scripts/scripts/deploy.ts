import { ethers, run } from "hardhat";

async function main() {
  console.log("🚀 Starting deployment process for Layer Infinite Protocol...");

  // 1. جلب المصنع الخاص بالعقد الذكي المطور
  const InfiniteDelegationEngine = await ethers.getContractFactory("InfiniteDelegationEngine");
  
  console.log("⏳ Deploying InfiniteDelegationEngine contract...");
  
  // 2. بدء عملية النشر على الشبكة المحددة في الأمر
  const ide = await InfiniteDelegationEngine.deploy();
  await ide.waitForDeployment();

  const contractAddress = await ide.getAddress();
  console.log(`✅ InfiniteDelegationEngine successfully deployed to: ${contractAddress}`);

  // 3. التحقق التلقائي من العقد (Verification) إذا لم تكن شبكة محلية
  const network = await ethers.provider.getNetwork();
  const localChainIds = [31337, 1337]; // شبكات هاردات المحتفظة محليًا

  if (!localChainIds.includes(Number(network.chainId))) {
    console.log("⏳ Waiting for block confirmations before starting verification...");
    
    // الانتظار لـ 5 تأكيدات كتل لضمان مزامنة المستكشف للعقد الجديد
    await ide.deploymentTransaction()?.wait(5);

    console.log(`🔍 Verifying contract on Etherscan/Blockscout for Chain ID: ${network.chainId}...`);
    try {
      await run("verify:verify", {
        address: contractAddress,
        constructorArguments: [],
      });
      console.log("🎉 Contract verification completed successfully!");
    } catch (error: any) {
      if (error.message.toLowerCase().includes("already verified")) {
        console.log("ℹ️ Contract is already verified on the explorer.");
      } else {
        console.error("❌ Verification failed:", error);
      }
    }
  } else {
    console.log("ℹ️ Local network detected. Skipping verification process.");
  }
}

// تشغيل السكريبت ومعالجة الأخطاء
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("🚨 Deployment script crashed:", error);
    process.exit(1);
  });
