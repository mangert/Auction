import fs from "fs";
import path from "path";
import hre, { ethers } from "hardhat";

async function main() {
    console.log("DEPLOYING...");
    const [deployer, owner] = await ethers.getSigners();

    const auction_Factory = await ethers.getContractFactory("Auction");
    const auction = await auction_Factory.deploy();    
    await auction.waitForDeployment(); 
    
    const address = await auction.getAddress();
    console.log("Deployed auction at:", address);
        
        
    const configPath = path.resolve(__dirname, "./config.ts");
    let configContent = fs.readFileSync(configPath, "utf8");
    
    const newContent = configContent.replace(
    /const auction_contractAddress = ".*?";/,
    `const auction_contractAddress = "${address}";`
      );
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error); 
        process.exit(1);
    });
