import { auction_contractAddress } from "./config"
import { run } from "hardhat";

async function main() {
  const contractAddress = auction_contractAddress; 
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

main();