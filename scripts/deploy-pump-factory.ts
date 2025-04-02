import { ethers } from "hardhat";
import fs from "fs";
import path from "path";
import * as dotenv from "dotenv";
dotenv.config();
async function main() {
  const [deployer] = await ethers.getSigners();
  const data = JSON.parse(
    fs.readFileSync(path.join(__dirname, "deployment.json"), "utf-8")
  );
  const { wethAddress, uniswapRouterAddress } = data;
  // Retrieve the contract factory for PumpFactory
  const PumpFactory = await ethers.getContractFactory("PumpFactory", deployer);

  const createTokenFee = ethers.parseEther("1000");
  const benefeciary = `${process.env.OWNER_ADDRESS}`;

  // Deploy the contract
  const tx = await PumpFactory.deploy(
    wethAddress,
    uniswapRouterAddress,
    createTokenFee,
    benefeciary
  );
  const pumpFactoryAddress = await tx.getAddress();
  fs.writeFileSync(
    path.join(__dirname, "deployment.json"),
    JSON.stringify(
      {
        ...data,
        pumpFactoryAddress,
      },
      null,
      2
    )
  );
  console.log("Deployment data saved to deployment.json");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
