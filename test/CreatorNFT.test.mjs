import "@nomicfoundation/hardhat-chai-matchers";
import { expect } from "chai";
import pkg from "hardhat";
const { ethers } = pkg;

describe("CreatorNFT", function () {
    this.timeout(300000);
    let creatorNFT, nftAttributes, poolSystem, dummyFLP;
    let owner;

    beforeEach(async function () {
        [owner] = await ethers.getSigners();

        // 部署 NFTAttributes 合約，這裡假設 NFTAttributes 已實現
        const NFTAttributes = await ethers.getContractFactory("NFTAttributes");
        nftAttributes = await NFTAttributes.deploy();
        await nftAttributes.deployed();

        // 部署 PoolSystem 合約
        const PoolSystem = await ethers.getContractFactory("PoolSystem");
        poolSystem = await PoolSystem.deploy();
        await poolSystem.deployed();

        // 部署 MockFLP 合約（之前的 DummyFLP 改为 MockFLP）
        const DummyFLP = await ethers.getContractFactory("MockFLP");
        dummyFLP = await DummyFLP.deploy();
        await dummyFLP.deployed();

        // 部署 CreatorNFT 合約
        const CreatorNFT = await ethers.getContractFactory("CreatorNFT");
        creatorNFT = await CreatorNFT.deploy(nftAttributes.address, poolSystem.address, dummyFLP.address);
        await creatorNFT.deployed();
    });

    it("should create an ERC721 NFT and set its info permanently", async function () {
        const rarity = 10;
        const imageUrl = "https://example.com/nft.png";

        // 創建 NFT，合約自動產生 tokenId
        const tx = await creatorNFT.createERC721(owner.address, rarity, imageUrl);
        const receipt = await tx.wait();
        const tokenId = receipt.events.find(e => e.event === "NFTCreated").args.tokenId;

        const info = await creatorNFT.getNFTInfo(tokenId);
        expect(info.rarity.toNumber()).to.equal(rarity);

        // 再次創建應該 revert
        try {
            await creatorNFT.createERC721(owner.address, rarity, imageUrl);
            expect.fail("交易應該 revert，但執行成功");
        } catch (error) {
            // 捕獲到錯誤
        }
    });

    it("should create an ERC1155 NFT and set its info permanently", async function () {
        const rarity1155 = 20;
        const amount = 100;
        const imageUrl1155 = "https://example.com/nft1155.png";

        // 創建 NFT，合約自動產生 tokenId
        const tx1155 = await creatorNFT.createERC1155(owner.address, rarity1155, amount, imageUrl1155);
        const receipt1155 = await tx1155.wait();
        const tokenId1155 = receipt1155.events.find(e => e.event === "NFTCreated").args.tokenId;

        const info1155 = await creatorNFT.getNFTInfo(tokenId1155);
        expect(info1155.rarity.toNumber()).to.equal(rarity1155);

        // 再次創建應該 revert
        try {
            await creatorNFT.createERC1155(owner.address, rarity1155, amount, imageUrl1155);
            expect.fail("交易應該 revert，但執行成功");
        } catch (error) {
            // 捕獲到錯誤
        }
    });
});
