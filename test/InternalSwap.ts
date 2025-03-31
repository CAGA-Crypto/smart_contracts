import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer } from "ethers";
import * as dotenv from "dotenv";
import {
  IWETH9__factory,
  PumpFactory,
  PumpFactory__factory,
} from "../typechain-types";
dotenv.config();

describe("InternalSwap Contract", function () {
  let internalSwap: any;
  let weth: Contract;
  let pumpFactory: any;
  let userToken: any;
  let owner: Signer;
  let addr1: Signer;
  let addr2: Signer;
  let addrs: Signer[];

  // beforeEach(async function () {
  //   [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

  //   const WETH = IWETH9__factory.connect(`${process.env.WETH}`);
  //   const wethAddress = await WETH.getAddress();

  //   const PumpFactory = await ethers.getContractFactory("PumpFactory");
  //   pumpFactory = await PumpFactory.deploy(
  //     wethAddress,
  //     `${process.env.UNISWAP_ROUTER_V2}`,
  //     75000000000000000
  //   );
  //   await pumpFactory.deployed();

  //   const UserToken = await ethers.getContractFactory("UserToken");
  //   userToken = await UserToken.deploy(
  //     "User Token",
  //     "UTK",
  //     ethers.parseEther("1000000"),
  //     "",
  //     "",
  //     "",
  //     "",
  //     await owner.getAddress()
  //   );
  //   await userToken.deployed();

  //   // const InternalSwap = await ethers.getContractFactory("InternalSwap");
  //   // internalSwap = await InternalSwap.deploy(
  //   //   userToken.address,
  //   //   wethAddress,
  //   //   `${process.env.UNISWAP_ROUTER_V2}`,
  //   //   await owner.getAddress()
  //   // );
  //   // await internalSwap.deployed();
  //   pumpFactory.connect("");
  // });

  describe("Functionality", function () {
    it("Should swap UserToken to WETH", async function () {
      // Approve tokens for the swap
      await userToken.approve(internalSwap.address, ethers.parseEther("1000"));
      await internalSwap.addUserTokenReserve(ethers.parseEther("1000"));

      // Perform the swap
      await internalSwap.swapUserTokenToWeth(
        ethers.parseEther("100"),
        ethers.parseEther("10")
      );

      // Check balances
      const userTokenBalance = await userToken.balanceOf(
        await owner.getAddress()
      );
      const wethBalance = await weth.balanceOf(await owner.getAddress());
      expect(userTokenBalance).to.be.equal(ethers.parseEther("900"));
      expect(wethBalance).to.be.greaterThan(ethers.parseEther("10"));
    });

    it("Should swap WETH to UserToken", async function () {
      // Approve WETH for the swap
      await weth.deposit({ value: ethers.parseEther("10") });
      await weth.approve(internalSwap.address, ethers.parseEther("10"));
      await internalSwap.addWethReserve(ethers.parseEther("10"));

      // Perform the swap
      await internalSwap.swapWethToUserToken(
        ethers.parseEther("1"),
        ethers.parseEther("100")
      );

      // Check balances
      const userTokenBalance = await userToken.balanceOf(
        await owner.getAddress()
      );
      const wethBalance = await weth.balanceOf(await owner.getAddress());
      expect(userTokenBalance).to.be.greaterThan(ethers.parseEther("100"));
      expect(wethBalance).to.be.lessThan(ethers.parseEther("10"));
    });

    it("Should calculate wethOverUserTokenValueAndPrice correctly", async function () {
      // Set up reserves
      await userToken.approve(internalSwap.address, ethers.parseEther("1000"));
      await internalSwap.addUserTokenReserve(ethers.parseEther("1000"));
      await weth.deposit({ value: ethers.parseEther("10") });
      await weth.approve(internalSwap.address, ethers.parseEther("10"));
      await internalSwap.addWethReserve(ethers.parseEther("10"));

      // Perform the calculation
      const [value, price] = await internalSwap.wethOverUserTokenValueAndPrice(
        ethers.parseEther("100"),
        0,
        0,
        0,
        false
      );
      expect(value).to.be.gt(0);
      expect(price).to.be.gt(0);
    });

    it("Should calculate wethOverUserTokenValueAndPriceFee correctly", async function () {
      // Set up reserves
      await userToken.approve(internalSwap.address, ethers.parseEther("1000"));
      await internalSwap.addUserTokenReserve(ethers.parseEther("1000"));
      await weth.deposit({ value: ethers.parseEther("10") });
      await weth.approve(internalSwap.address, ethers.parseEther("10"));
      await internalSwap.addWethReserve(ethers.parseEther("10"));

      // Perform the calculation
      const [value, price] =
        await internalSwap.wethOverUserTokenValueAndPriceFee(
          ethers.parseEther("100"),
          0,
          0,
          0
        );
      expect(value).to.be.gt(0);
      expect(price).to.be.gt(0);
    });
  });
});
