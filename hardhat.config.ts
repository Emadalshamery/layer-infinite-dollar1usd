import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200, // تحسين كود النشر وتقليل استهلاك الغاز عند النشر
      },
    },
  },

  networks: {
    hardhat: {
      chainId: 31337,
    },
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 11155111,
    },
    mainnet: {
      url: process.env.ETHEREUM_RPC_URL || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 1,
    },
    base: {
      url: process.env.BASE_RPC_URL || "https://mainnet.base.org",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 8453,
    },
    zora: {
      url: process.env.ZORA_RPC_URL || "https://rpc.zora.energy",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 7777777,
    },
  },

  // إعدادات محلل تقارير الغاز لإثبات كفاءة أداء بروتوكول Layer Infinite
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined ? process.env.REPORT_GAS === "true" : true,
    currency: "USD",
    coinmarketcap: process.env.COINMARKETCAP_API_KEY || "", // لجلب أسعار الغاز الفلكية الحية ومقابلها بالدولار
    token: "ETH",
    outputFile: "gas-report.txt", // حفظ التقرير في ملف نصي ليقرأه المستثمرون مباشرة
    noColors: true,
  },

  // التحقق التلقائي من العقود على مستكشفات الشبكات (Verification)
  etherscan: {
    apiKey: {
      mainnet: process.env.ETHERSCAN_API_KEY || "",
      sepolia: process.env.ETHERSCAN_API_KEY || "",
      base: process.env.BASESCAN_API_KEY || "",
    },
  },

  paths: {
    sources: "./contracts",
    tests: "./test", // تم تعديله إلى المسار القياسي لحماية هيكلية جيت هاب
    cache: "./cache",
    artifacts: "./artifacts",
  },
};

export default config;
