import { ethers } from "hardhat";
import fs from "fs";
import path from "path";
import { cagaFactoryAbi, wethAbi } from "./abis";

async function main() {
  const [deployer] = await ethers.getSigners();
  const data = JSON.parse(
    fs.readFileSync(path.join(__dirname, "deployment.json"), "utf-8")
  );
  const { wethAddress, pumpFactoryAddress } = data;
  const weth = new ethers.Contract(wethAddress, wethAbi, deployer);
  const tx = await weth.approve(pumpFactoryAddress, ethers.parseEther("20000"));

  console.log({
    tx,
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
