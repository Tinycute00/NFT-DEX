import { expect } from "chai";
import pkg from "hardhat";
const { ethers } = pkg;

describe("CreatorNFT1155Unlimited", function () {
  let creatorNFT1155;
  let owner;
  const uri = "https://example.com/metadata/";

  beforeEach(async function () {
    [owner] = await ethers.getSigners();
    const CreatorNFT1155Unlimited = await ethers.getContractFactory("CreatorNFT1155Unlimited");
    creatorNFT1155 = await CreatorNFT1155Unlimited.deploy(uri);
    await creatorNFT1155.deployed();
  });

  it("should allow adding part configuration before freezing", async function () {
    // Add a part configuration
    const rarityForOption = [50, 80];
    const supplyLimit = [100, 200];

    const tx = await creatorNFT1155.addPartConfig("Background", rarityForOption, supplyLimit);
    const receipt = await tx.wait();
    const event = receipt.events.find(e => e.event === "PartAdded");
    expect(event).to.exist;
  });

  it("should freeze configuration on first mint and mint NFT correctly", async function () {
    // First, add a part configuration since the contract might require configuration
    const rarityForOption = [60, 90];
    const supplyLimit = [50, 150];
    await creatorNFT1155.addPartConfig("Accessory", rarityForOption, supplyLimit);

    // Prepare selections array for parts, here only one part so length is 1
    const selections = [0];
    // Mint NFT1155
    const tx = await creatorNFT1155.mintNFT1155(owner.address, selections);
    const receipt = await tx.wait();

    // Check that token id equals 1 (first minted)
    const event = receipt.events.find(e => e.event === "NFTMinted");
    expect(event).to.exist;
    const tokenId = event.args.tokenId.toNumber();
    expect(tokenId).to.equal(1);

    // Check that configuration is frozen
    const frozen = await creatorNFT1155.configurationFrozen();
    expect(frozen).to.be.true;
  });
}); 