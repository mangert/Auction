import fs from "fs";
import path from "path";
import hre, { ethers, run } from "hardhat";
//скрипт для деплоя и верификации
async function main() {
    
    const contractName = process.env.CONTRACT || "Auction";
    
    //деплой
    console.log("DEPLOYING...");
    const [deployer, owner] = await ethers.getSigners();

    const auction_Factory = await ethers.getContractFactory("Auction");
    const auction = await auction_Factory.deploy();    
    await auction.waitForDeployment(); 
    
    const contractAddress = await auction.getAddress();
    console.log("Deployed auction at:", contractAddress);
   
    //верификация
    console.log("VERIFY...");
    const constructorArgs: any[] = []; // если без аргументов
    
    try {
       await run("verify:verify", {
         address: contractAddress,
         constructorArguments: constructorArgs,
       });
       console.log("Verification successful!");
     } catch (error: any) {
       if (error.message.toLowerCase().includes("already verified")) {
         console.log("Already verified");
       } else {
         console.error("Verification failed:", error);
       }
     }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error); 
        process.exit(1);
    });
