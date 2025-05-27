import "hardhat-gas-reporter";
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import dotenv from "dotenv";

dotenv.config(); 

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.29",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  networks: {
    hardhat: {
      chainId: 1337,
      initialBaseFeePerGas: 0,
    },
    sepolia: {
      url: process.env.ALCHEMY_API_URL || "",
      accounts: process.env.PRIVATE_KEY ? [`0x${process.env.PRIVATE_KEY}`] : [],
      chainId: 11155111,
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY || "",
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS === "true",
    currency: "ETH", 
  },
};

export default config;
