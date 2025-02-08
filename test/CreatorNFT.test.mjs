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

        // Deploy the NFTAttributes contract; assume NFTAttributes is implemented
        const NFTAttributes = await ethers.getContractFactory("NFTAttributes");
        nftAttributes = await NFTAttributes.deploy();
        await nftAttributes.deployed();

        // Deploy the PoolSystem contract
        const PoolSystem = await ethers.getContractFactory("PoolSystem");
        poolSystem = await PoolSystem.deploy();
        await poolSystem.deployed();

        // Deploy the MockFLP contract (previously DummyFLP changed to MockFLP)
        const DummyFLP = await ethers.getContractFactory("MockFLP");
        dummyFLP = await DummyFLP.deploy();
        await dummyFLP.deployed();

        // Deploy the CreatorNFT contract
        const CreatorNFT = await ethers.getContractFactory("CreatorNFT");
        creatorNFT = await CreatorNFT.deploy(nftAttributes.address, poolSystem.address, dummyFLP.address);
        await creatorNFT.deployed();
    });

    it("should create an ERC721 NFT and set its info permanently", async function () {
        const rarity = 10;
        const imageUrl = "https://example.com/nft.png";

        // Create NFT; the contract auto-generates the tokenId
        const tx = await creatorNFT.createERC721(owner.address, rarity, imageUrl);
        const receipt = await tx.wait();
        const tokenId = receipt.events.find(e => e.event === "NFTCreated").args.tokenId;

        const info = await creatorNFT.getNFTInfo(tokenId);
        expect(info.rarity.toNumber()).to.equal(rarity);

        // Attempting to create again should revert
        try {
            await creatorNFT.createERC721(owner.address, rarity, imageUrl);
            expect.fail("Transaction should revert but succeeded");
        } catch (error) {
            // Error caught
        }
    });

    it("should create an ERC1155 NFT and set its info permanently", async function () {
        const rarity1155 = 20;
        const amount = 100;
        const imageUrl1155 = "https://example.com/nft1155.png";

        // Create NFT; the contract auto-generates the tokenId
        const tx1155 = await creatorNFT.createERC1155(owner.address, rarity1155, amount, imageUrl1155);
        const receipt1155 = await tx1155.wait();
        const tokenId1155 = receipt1155.events.find(e => e.event === "NFTCreated").args.tokenId;

        const info1155 = await creatorNFT.getNFTInfo(tokenId1155);
        expect(info1155.rarity.toNumber()).to.equal(rarity1155);

        // Attempting to create again should revert
        try {
            await creatorNFT.createERC1155(owner.address, rarity1155, amount, imageUrl1155);
            expect.fail("Transaction should revert but succeeded");
        } catch (error) {
            // Error caught
        }
    });
});
