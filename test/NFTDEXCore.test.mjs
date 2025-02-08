import '@nomicfoundation/hardhat-chai-matchers';
import { expect } from "chai";
import pkg from "hardhat";
const { ethers } = pkg;

describe("NFTDEXCore", function () {
    let nftDexCore;
    let owner, addr1, addr2;

    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();

        // 部署 NFTDEXCore 合約
        const NFTDEXCore = await ethers.getContractFactory("NFTDEXCore");
        nftDexCore = await NFTDEXCore.deploy();
        await nftDexCore.deployed();
    });

    it("should list an NFT", async function () {
        const tokenId = 1;
        const price = ethers.utils.parseEther("1");

        await nftDexCore.listNFT(tokenId, price);
        const listing = await nftDexCore.getListing(tokenId);

        expect(listing.seller).to.equal(owner.address);
        expect(listing.price.toString()).to.equal(price.toString());
    });

    it("should cancel an NFT listing", async function () {
        const tokenId = 1;
        const price = ethers.utils.parseEther("1");

        await nftDexCore.listNFT(tokenId, price);
        await nftDexCore.cancelListing(tokenId);
        const listing = await nftDexCore.getListing(tokenId);

        expect(listing.seller).to.equal(ethers.constants.AddressZero);
    });

    it("should buy an NFT", async function () {
        const tokenId = 1;
        const price = ethers.utils.parseEther("1");

        // 設置平台費地址為官方地址
        const officialAddress = "0xe9eb54cdd77e68196ee7e2899570188bcdedf3e0";
        const tx1 = await nftDexCore.connect(owner).setPlatformFeeAddress(officialAddress);
        const receipt1 = await tx1.wait();
        console.log('Set Platform Fee Address Transaction:', receipt1.transactionHash);

        // 部署 PoolSystem 並設置
        const PoolSystem = await ethers.getContractFactory("PoolSystem");
        const poolSystem = await PoolSystem.deploy();
        await poolSystem.deployed();
        console.log('PoolSystem deployed at:', poolSystem.address);
        const tx2 = await nftDexCore.connect(owner).setPoolSystem(poolSystem.address);
        const receipt2 = await tx2.wait();
        console.log('Set PoolSystem Transaction:', receipt2.transactionHash);

        const currentPlatformFeeAddress = await nftDexCore.platformFeeAddress();
        console.log('Current Platform Fee Address:', currentPlatformFeeAddress);

        await nftDexCore.listNFT(tokenId, price);
        await nftDexCore.connect(addr1).buyNFT(tokenId, { value: price });

        const listing = await nftDexCore.getListing(tokenId);
        expect(listing.seller).to.equal(ethers.constants.AddressZero);
    });

    // 用户市場费用验证部分
    context("User Market Fee validations", function () {
      const tokenId = 99; // 使用一個未在其他測試中使用的 tokenId
      const price = ethers.utils.parseEther("1");
      let sellerInitialBalance, platformInitialBalance, sellerAddress, platformSigner;
      
      beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();
        
        // 重新部署新的 NFTDEXCore 實例，確保初始平台費地址為 0
        const NFTDEXCore = await ethers.getContractFactory("NFTDEXCore");
        nftDexCore = await NFTDEXCore.deploy();
        await nftDexCore.deployed();
        
        // 不設定平台費地址，保持預設為 0
        sellerAddress = owner.address;
        platformSigner = addr2;
        
        await nftDexCore.listNFT(tokenId, price);
        sellerInitialBalance = await ethers.provider.getBalance(sellerAddress);
        platformInitialBalance = await ethers.provider.getBalance(platformSigner.address);
      });
      
      it("should revert buyNFT if platformFeeAddress is not set", async function () {
        try {
          await nftDexCore.connect(addr1).buyNFT(tokenId, { value: price });
          // 若未回退，則測試失敗
          assert.fail("Expected buyNFT to revert, but it did not");
        } catch (error) {
          expect(error.message).to.include("Platform fee address not set");
        }
      });
    });
}); 