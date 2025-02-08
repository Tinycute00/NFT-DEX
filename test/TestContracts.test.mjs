import { expect } from "chai";
import pkg from "hardhat";
import '@nomicfoundation/hardhat-chai-matchers';
const { ethers } = pkg;

// Test basic functionalities of all NFT DEX related contracts
// Includes TestNFTDEXCore (for testing _mintFLP), market order functionalities (listNFT, cancelListing, buyNFT)

describe("NFT DEX All Contracts Tests", function () {
  let testNftDexCore;
  let poolSystem, dummyFLP;
  let owner, addr1, addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    // Deploy DummyFLP contract
    const DummyFLP = await ethers.getContractFactory("MockFLP");
    dummyFLP = await DummyFLP.deploy();
    await dummyFLP.deployed();

    // Deploy PoolSystem contract
    const PoolSystem = await ethers.getContractFactory("PoolSystem");
    poolSystem = await PoolSystem.deploy();
    await poolSystem.deployed();

    // Deploy TestNFTDEXCore contract
    const TestNFTDEXCore = await ethers.getContractFactory("TestNFTDEXCore");
    testNftDexCore = await TestNFTDEXCore.deploy();
    await testNftDexCore.deployed();

    // Set FLP and PoolSystem addresses
    await testNftDexCore.setFLPContract(dummyFLP.address);
    await testNftDexCore.setPoolSystem(poolSystem.address);
  });

  describe("Test mintFLP functionality", function () {
    it("should mint FLP and update pool correctly", async function () {
      // Test _mintFLP (via testMintFLP method)
      // Choose a weight value, e.g., 1000
      const weight = 1000;
      const tx = await testNftDexCore.testMintFLP(owner.address, weight);
      const receipt = await tx.wait();

      // Check total supply of DummyFLP
      const flpTokenId = await dummyFLP.totalSupply();
      // Initial totalSupply is 0, then set to flpTokenId, expected to be 1
      expect(flpTokenId.toNumber()).to.equal(1);

      // Check if PoolSystem is updated
      // Calculation: extraFee = (weight * 10) / 100 = (1000 * 10) / 100 = 100
      // In PoolSystem, when isSystemFee is true, calculate premiumAmount = (100 * 200) / 1000 = 20
      const marketInfo = await poolSystem.getMarketInfo();
      expect(marketInfo.premiumPool.toNumber()).to.equal(20);
    });
  });

  describe("NFTDEXCore", function () {
    // Tests for Market order functionalities
    context("Market order functionalities", function () {
      beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();
        
        // Re-deploy a new instance of NFTDEXCore to ensure initial platform fee address is 0
        const NFTDEXCore = await ethers.getContractFactory("NFTDEXCore");
        nftDexCore = await NFTDEXCore.deploy();
        await nftDexCore.deployed();
        
        // Do not set platform fee address, keep default 0
        sellerAddress = owner.address;
        platformSigner = addr2;
        
        await nftDexCore.listNFT(tokenId, price);
        sellerInitialBalance = await ethers.provider.getBalance(sellerAddress);
        platformInitialBalance = await ethers.provider.getBalance(platformSigner.address);
      });
      
      it("should revert buyNFT if platformFeeAddress is not set", async function () {
        try {
          await nftDexCore.connect(addr1).buyNFT(tokenId, { value: price });
          // If not reverted, the test fails
          assert.fail("Expected buyNFT to revert, but it did not");
        } catch (error) {
          expect(error.message).to.include("Platform fee address not set");
        }
      });
    });
  });
}); 