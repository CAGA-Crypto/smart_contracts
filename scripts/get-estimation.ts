import hre from "hardhat";
import { ethers } from "ethers";
import { InternalSwap__factory } from "../typechain-types";

async function normalPrice() {
  const accounts = await hre.ethers.getSigners();
  const contract = InternalSwap__factory.connect(
    "0x57868a53664c5fa725752d1bdb5c2ac254d9d519",
    accounts[0]
  );
  const data1 = await contract.wethOverUserTokenValueAndPrice(
    ethers.parseEther("10000"),
    0,
    0,
    0,
    false
  );
  console.log("===========================");
  console.log("Sell 10_000 User Token with 10000 TokenIn");
  console.log(`Estimation: ${ethers.formatEther(data1[0])}`);
  console.log(`Price: ${ethers.formatEther(data1[1])}`);
  console.log("===========================");
  console.log("\n");

  const data2 = await contract.wethOverUserTokenValueAndPrice(
    0,
    ethers.parseEther("0.0043255"),
    0,
    0,
    false
  );
  console.log("===========================");
  console.log("Buy 10_000 User Token with 0.0043255 WETHIn");
  console.log(`Estimation: ${ethers.formatEther(data2[0])}`);
  console.log(`Price: ${ethers.formatEther(data2[1])}`);
  console.log("===========================");
  console.log("\n");

  const data3 = await contract.wethOverUserTokenValueAndPrice(
    0,
    0,
    0,
    ethers.parseEther("0.0043255"),
    false
  );
  console.log("===========================");
  console.log("Sell 10_000 User Token with 0.0043255 WETHOut");
  console.log(`Estimation: ${ethers.formatEther(data3[0])}`);
  console.log(`Price: ${ethers.formatEther(data3[1])}`);
  console.log("===========================");
  console.log("\n");

  const data4 = await contract.wethOverUserTokenValueAndPrice(
    0,
    0,
    ethers.parseEther("10000"),
    0,
    false
  );
  console.log("===========================");
  console.log("Buy 10_000 User Token with 10000 TokenOut");
  console.log(`Estimation: ${ethers.formatEther(data4[0])}`);
  console.log(`Price: ${ethers.formatEther(data4[1])}`);
  console.log("===========================");
  console.log("\n");
}

async function testRequireUserTokenIn() {
  const accounts = await hre.ethers.getSigners();
  const contract = InternalSwap__factory.connect(
    "0x57868a53664c5fa725752d1bdb5c2ac254d9d519",
    accounts[0]
  );
  await contract.wethOverUserTokenValueAndPrice(
    ethers.parseEther("10000"),
    ethers.parseEther("10000"),
    ethers.parseEther("10000"),
    ethers.parseEther("10000"),
    false
  );
}
async function testRequireWethIn() {
  const accounts = await hre.ethers.getSigners();
  const contract = InternalSwap__factory.connect(
    "0x57868a53664c5fa725752d1bdb5c2ac254d9d519",
    accounts[0]
  );
  await contract.wethOverUserTokenValueAndPrice(
    0,
    ethers.parseEther("10000"),
    ethers.parseEther("10000"),
    ethers.parseEther("10000"),
    false
  );
}
async function testRequireUserTokenOut() {
  const accounts = await hre.ethers.getSigners();
  const contract = InternalSwap__factory.connect(
    "0x57868a53664c5fa725752d1bdb5c2ac254d9d519",
    accounts[0]
  );
  await contract.wethOverUserTokenValueAndPrice(
    0,
    0,
    ethers.parseEther("10000"),
    ethers.parseEther("10000"),
    false
  );
}

async function testBuyMore80Percent() {
  const accounts = await hre.ethers.getSigners();
  const contract = InternalSwap__factory.connect(
    "0x35198d07e80bc541b5f91034ed1b9c80694130b6",
    accounts[0]
  );
  const data = await contract.wethOverUserTokenValueAndPrice(
    0,
    0,
    ethers.parseEther("1000"),
    0,
    false
  );
  console.log("===========================");
  console.log(`Estimation: ${ethers.formatEther(data[0])}`);
  console.log(`Price: ${ethers.formatEther(data[1])}`);
  console.log("===========================");
  console.log("\n");
}

testBuyMore80Percent().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
