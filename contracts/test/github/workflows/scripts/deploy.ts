mkdir -p scripts
cat > scripts/deploy.ts <<'EOF'
import { ethers } from "hardhat";

async function main() {
  const Engine = await ethers.getContractFactory("InfiniteDelegationEngine");
  const engine = await Engine.deploy();
  await engine.deployed();
  console.log("InfiniteDelegationEngine deployed to:", engine.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOF
