import { ethers } from "hardhat";
import fs from "fs";
import path from "path";
import { cagaFactoryAbi, internalSwapAbi } from "./abis";

async function main() {
  const [deployer] = await ethers.getSigners();
  const data = JSON.parse(
    fs.readFileSync(path.join(__dirname, "deployment.json"), "utf-8")
  );
  const { pumpFactoryAddress, swapContractAddress } = data;

  const internalSwap = new ethers.Contract(
    swapContractAddress,
    internalSwapAbi,
    deployer
  );

  const wethAmountToSwap = ethers.parseEther("20000");

  // Call swapWethToUserToken with the amount to swap
  const tx = await internalSwap.swapWethToUserToken(wethAmountToSwap, {
    value: wethAmountToSwap,
  });

  // Wait for the transaction to be confirmed
  const receipt = await tx.wait();

  // Find the Swap event
  const event = receipt.logs.find((log: any) => {
    try {
      return log.eventName === "Swap";
    } catch (e) {
      return false;
    }
  });

  if (event) {
    const rawPrice = event.args.price;
    const actualPrice = rawPrice / 100n; // Convert to actual price by dividing by 100

    console.log("Swap Event Details:");
    console.log({
      typeSwap: event.args.typeSwap,
      wethAmount: ethers.formatEther(event.args.weth),
      userTokenAmount: ethers.formatEther(event.args.userToken),
      rawPrice: rawPrice.toString(),
      actualPrice: actualPrice.toString(),
      priceInEther: ethers.formatEther(actualPrice),
      tokenAddress: event.args.tokenAddress,
      from: event.args.from,
    });

    // Calculate and show the actual price per token
    const wethAmount = event.args.weth;
    const userTokenAmount = event.args.userToken;
    const pricePerToken = (wethAmount * 100n) / userTokenAmount;
    console.log("\nPrice Analysis:");
    console.log({
      pricePerToken: pricePerToken.toString(),
      pricePerTokenInEther: ethers.formatEther(pricePerToken),
      tokensPerWeth: (userTokenAmount * 100n) / wethAmount,
    });
  } else {
    console.log("No Swap event found in transaction");
  }

  console.log("\nTransaction hash:", tx.hash);
  console.log("Transaction receipt:", receipt);
}

main().catch((error) => {
  console.error("Error in script execution:", error);
  process.exitCode = 1;
});
