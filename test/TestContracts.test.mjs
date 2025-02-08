import { expect } from "chai";
import pkg from "hardhat";
import '@nomicfoundation/hardhat-chai-matchers';
const { ethers } = pkg;

// 測試所有 NFT DEX 相關合約的基礎功能
// 包括 TestNFTDEXCore (用於測試 _mintFLP)、市場訂單功能 (listNFT, cancelListing, buyNFT)

describe("NFT DEX All Contracts Tests", function () {
  let testNftDexCore;
  let poolSystem, dummyFLP;
  let owner, addr1, addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    // 部署 DummyFLP 合約
    const DummyFLP = await ethers.getContractFactory("MockFLP");
    dummyFLP = await DummyFLP.deploy();
    await dummyFLP.deployed();

    // 部署 PoolSystem 合約
    const PoolSystem = await ethers.getContractFactory("PoolSystem");
    poolSystem = await PoolSystem.deploy();
    await poolSystem.deployed();

    // 部署 TestNFTDEXCore 合約
    const TestNFTDEXCore = await ethers.getContractFactory("TestNFTDEXCore");
    testNftDexCore = await TestNFTDEXCore.deploy();
    await testNftDexCore.deployed();

    // 設置 FLP 與 PoolSystem 地址
    await testNftDexCore.setFLPContract(dummyFLP.address);
    await testNftDexCore.setPoolSystem(poolSystem.address);
  });

  describe("Test mintFLP functionality", function () {
    it("should mint FLP and update pool correctly", async function () {
      // 測試 _mintFLP（通過 testMintFLP 方法）
      // 選擇一個權重值，例如 1000
      const weight = 1000;
      const tx = await testNftDexCore.testMintFLP(owner.address, weight);
      const receipt = await tx.wait();

      // 檢查 DummyFLP 的總發行量
      const flpTokenId = await dummyFLP.totalSupply();
      // 初始 totalSupply 為 0，之後會設定為 flpTokenId，預期為 1
      expect(flpTokenId.toNumber()).to.equal(1);

      // 檢查 PoolSystem 是否更新
      // 計算：extraFee = (weight * 10) / 100 = (1000 * 10) / 100 = 100
      // 在 PoolSystem 中，當 isSystemFee 為 true 時，計算 premiumAmount = (100 * 200) / 1000 = 20
      const marketInfo = await poolSystem.getMarketInfo();
      expect(marketInfo.premiumPool.toNumber()).to.equal(20);
    });
  });

  describe("NFTDEXCore", function () {
    // 用于 Market order functionalities 部分的测试
    context("Market order functionalities", function () {
      beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();
        
        // 部署 DummyFLP 合约
        const DummyFLP = await ethers.getContractFactory("MockFLP");
        dummyFLP = await DummyFLP.deploy();
        await dummyFLP.deployed();
        
        // 部署 PoolSystem 合约
        const PoolSystem = await ethers.getContractFactory("PoolSystem");
        poolSystem = await PoolSystem.deploy();
        await poolSystem.deployed();
        
        // 部署 TestNFTDEXCore 合约，并设置 FLP 与 PoolSystem 地址
        const TestNFTDEXCore = await ethers.getContractFactory("TestNFTDEXCore");
        testNftDexCore = await TestNFTDEXCore.deploy();
        await testNftDexCore.deployed();
        await testNftDexCore.setFLPContract(dummyFLP.address);
        await testNftDexCore.setPoolSystem(poolSystem.address);
        // 由 owner 设置平台费用地址为官方地址
        const officialAddress = "0xe9eb54cdd77e68196ee7e2899570188bcdedf3e0";
        await testNftDexCore.connect(owner).setPlatformFeeAddress(officialAddress);
      });
      
      it("should list an NFT correctly", async function () {
        const tokenId = 1;
        const price = ethers.utils.parseEther("1");
        await testNftDexCore.listNFT(tokenId, price);
        const listing = await testNftDexCore.getListing(tokenId);
        expect(listing.seller).to.equal(owner.address);
        expect(listing.price.toString()).to.equal(price.toString());
      });
      
      it("should cancel an NFT listing", async function () {
        const tokenId = 1;
        const price = ethers.utils.parseEther("1");
        await testNftDexCore.listNFT(tokenId, price);
        await testNftDexCore.cancelListing(tokenId);
        const listing = await testNftDexCore.getListing(tokenId);
        expect(listing.seller).to.equal(ethers.constants.AddressZero);
      });
      
      it("should buy an NFT correctly", async function () {
        // 显式再次设置平台费用地址（确保值正确），并转换为小写比较
        const officialAddress = "0xe9eb54cdd77e68196ee7e2899570188bcdedf3e0";
        await testNftDexCore.connect(owner).setPlatformFeeAddress(officialAddress);
        const currentPlatformFeeAddress = await testNftDexCore.platformFeeAddress();
        expect(currentPlatformFeeAddress.toLowerCase()).to.equal(officialAddress);
        
        const tokenId = 50;
        const price = ethers.utils.parseEther("1");
        await testNftDexCore.connect(owner).listNFT(tokenId, price);
        const tx = await testNftDexCore.connect(addr1).buyNFT(tokenId, { value: price });
        const receipt = await tx.wait();
        
        const listing = await testNftDexCore.getListing(tokenId);
        expect(listing.seller).to.equal(ethers.constants.AddressZero);
        
        const nftBoughtEvent = receipt.events.find(e => e.event === "NFTBought");
        expect(nftBoughtEvent).to.exist;
        expect(nftBoughtEvent.args.tokenId.toNumber()).to.equal(tokenId);
        expect(nftBoughtEvent.args.buyer).to.equal(addr1.address);
        expect(nftBoughtEvent.args.price.toString()).to.equal(price.toString());
      });
    });
    
    // 用户市场费用验证部分
    context("User Market Fee validations", function () {
      const tokenId = 99; // 使用一个未在其他测试中使用的 tokenId
      const price = ethers.utils.parseEther("1");
      let sellerInitialBalance, platformInitialBalance, sellerAddress, platformSigner;
      
      beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();
        
        // 重新部署新的 TestNFTDEXCore 实例，确保初始平台费地址为 0
        const TestNFTDEXCore = await ethers.getContractFactory("TestNFTDEXCore");
        testNftDexCore = await TestNFTDEXCore.deploy();
        await testNftDexCore.deployed();
        
        await testNftDexCore.setFLPContract(dummyFLP.address);
        await testNftDexCore.setPoolSystem(poolSystem.address);
        
        // 不设置平台费地址，保持默认 0
        sellerAddress = owner.address;
        platformSigner = addr2;
        
        await testNftDexCore.listNFT(tokenId, price);
        sellerInitialBalance = await ethers.provider.getBalance(sellerAddress);
        platformInitialBalance = await ethers.provider.getBalance(platformSigner.address);
      });
      
      it("should revert buyNFT if platformFeeAddress is not set", async function () {
        try {
          await testNftDexCore.connect(addr1).buyNFT(tokenId, { value: price });
          // 若未回退，則測試失敗
          assert.fail("Expected buyNFT to revert, but it did not");
        } catch (error) {
          expect(error.message).to.include("Platform fee address not set");
        }
      });
      
      it("should deduct 3% fee: seller gets 97%, platform gets 1%, and premiumPool increases by 2%", async function () {
        // 由 owner 设置平台费地址为平台接收地址
        await testNftDexCore.connect(owner).setPlatformFeeAddress(platformSigner.address);
        
        const fee = price.mul(3).div(100);
        const sellerNet = price.sub(fee);
        const expectedPlatformFee = price.mul(1).div(100);
        const expectedPoolFee = price.mul(2).div(100).mul(200).div(1000);
        
        const tx = await testNftDexCore.connect(addr1).buyNFT(tokenId, { value: price });
        const receipt = await tx.wait();
        
        const sellerFinalBalance = await ethers.provider.getBalance(sellerAddress);
        const delta = ethers.utils.parseEther("0.01");
        const balanceDiff = sellerFinalBalance.sub(sellerInitialBalance);
        expect(balanceDiff.gte(sellerNet.sub(delta))).to.be.true;
        expect(balanceDiff.lte(sellerNet.add(delta))).to.be.true;
        
        const platformFinalBalance = await ethers.provider.getBalance(platformSigner.address);
        const platformDiff = platformFinalBalance.sub(platformInitialBalance);
        expect(platformDiff.gte(expectedPlatformFee.sub(delta))).to.be.true;
        expect(platformDiff.lte(expectedPlatformFee.add(delta))).to.be.true;
        
        const marketInfo = await poolSystem.getMarketInfo();
        expect(marketInfo.premiumPool.toString()).to.equal(expectedPoolFee.toString());
      });
    });
  });
}); 