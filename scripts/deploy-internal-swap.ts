import { ethers } from "hardhat";
import fs from "fs";
import path from "path";
import { cagaFactoryAbi } from "./abis";

async function main() {
  const [deployer] = await ethers.getSigners();
  const data = JSON.parse(
    fs.readFileSync(path.join(__dirname, "deployment.json"), "utf-8")
  );
  const { pumpFactoryAddress } = data;
  const pumpFactory = new ethers.Contract(
    pumpFactoryAddress,
    cagaFactoryAbi,
    deployer
  );

  const liquidityToAdd = ethers.parseEther("20000");
  const fee = ethers.parseEther("1000");

  const totalValue = liquidityToAdd + fee;

  const tx = await pumpFactory.deployTokenAndInternalSwap(
    "Websocket",
    "WSS",
    "twitter",
    "telegram",
    "website",
    "imageUri",
    liquidityToAdd,
    { value: totalValue }
  );

  // Wait for the transaction to be mined
  const receipt = await tx.wait();

  // Find the InternalSwapDeployed event
  const event = receipt.logs.find((log: any) => {
    try {
      return log.eventName === "InternalSwapDeployed";
    } catch (e) {
      return false;
    }
  });

  if (event) {
    console.log("InternalSwapDeployed Event Details:");
    console.log({
      swapContract: event.args.swapContract,
      userToken: event.args.userToken,
      owner: event.args.owner,
      name: event.args.name,
      symbol: event.args.symbol,
      initialSupply: event.args.initialSupply.toString(),
      twitter: event.args.twitter,
      telegram: event.args.telegram,
      website: event.args.website,
      imageUri: event.args.imageUri,
      from: event.args.from,
    });

    // Update deployment.json with new addresses
    const newData = {
      ...data,
      swapContractAddress: event.args.swapContract,
      userTokenAddress: event.args.userToken,
    };

    fs.writeFileSync(
      path.join(__dirname, "deployment.json"),
      JSON.stringify(newData, null, 2)
    );
    console.log("Deployment data saved to deployment.json");
  } else {
    console.log("No InternalSwapDeployed event found in transaction");
  }

  console.log("Transaction hash:", tx.hash);
  console.log("Transaction receipt:", receipt);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
