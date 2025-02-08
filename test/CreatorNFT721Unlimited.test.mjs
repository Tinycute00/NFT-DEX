import { expect } from "chai";
import pkg from "hardhat";
const { ethers } = pkg;

describe("CreatorNFT721Unlimited", function () {
    let creatorNFT721;
    let owner;
    beforeEach(async function() {
         [owner] = await ethers.getSigners();
         const CreatorNFT721Unlimited = await ethers.getContractFactory("CreatorNFT721Unlimited");
         creatorNFT721 = await CreatorNFT721Unlimited.deploy("Test721", "T721");
         await creatorNFT721.deployed();
    });

    it("should mint an NFT and freeze configuration", async function() {
         const rarity = 10;
         const imageUrl = "https://example.com/nft.png";
         const tx = await creatorNFT721.mintNFT(owner.address, rarity, imageUrl);
         const receipt = await tx.wait();
         const event = receipt.events.find(e => e.event === "NFTMinted");
         expect(event).to.exist;
         const tokenId = event.args.tokenId.toNumber();
         expect(tokenId).to.equal(1);
         const frozen = await creatorNFT721.configurationFrozen();
         expect(frozen).to.be.true;
    });
}); 