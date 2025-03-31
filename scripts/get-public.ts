import hre from "hardhat";
import { ethers } from "ethers";
import { InternalSwap__factory } from "../typechain-types";
async function getReserveUserToken() {
  const accounts = await hre.ethers.getSigners();
  const contract = InternalSwap__factory.connect(
    "0x35198d07e80bc541b5f91034ed1b9c80694130b6",
    accounts[0]
  );
  const data = await contract.reserveUserToken();
  console.log("===========================");
  console.log(`reserveUserToken: ${ethers.formatEther(data)}`);
  console.log("===========================");
  console.log("\n");
}

getReserveUserToken().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
