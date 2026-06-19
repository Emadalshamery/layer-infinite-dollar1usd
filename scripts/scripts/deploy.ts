import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("نشر العقد باستخدام الحساب:", deployer.address);

  const IDE = await ethers.getContractFactory("InfiniteDelegationEngine");
  const ide = await IDE.deploy();

  await ide.waitForDeployment();

  console.log("تم نشر InfiniteDelegationEngine بنجاح على العنوان:", await ide.getAddress());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
