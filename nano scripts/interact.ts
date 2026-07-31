import { ethers } from "hardhat";
import * as fs from "fs";

async function main() {
  // قراءة معلومات النشر
  const deployment = JSON.parse(fs.readFileSync("deployment.json", "utf8"));
  const usd1Address = deployment.contracts.USD1;
  
  // الاتصال بالعقد
  const USD1 = await ethers.getContractFactory("Dollar1usd");
  const usd1 = USD1.attach(usd1Address);
  
  // الحصول على معلومات
  const name = await usd1.name();
  const symbol = await usd1.symbol();
  const totalSupply = await usd1.totalSupply();
  
  console.log(`📊 Token Info:`);
  console.log(`Name: ${name}`);
  console.log(`Symbol: ${symbol}`);
  console.log(`Total Supply: ${ethers.formatEther(totalSupply)} USD1`);
  
  // سك بعض العملات (إذا كنت المرسل)
  const [deployer] = await ethers.getSigners();
  const amount = ethers.parseEther("1000");
  await usd1.mint(await deployer.getAddress(), amount);
  console.log(`\n✅ Minted 1000 USD1 to ${await deployer.getAddress()}`);
}

main().catch(console.error);
