import { expect } from "chai";
import pkg from "hardhat";
const { ethers } = pkg;

describe("NFTAttributes", function () {
    let NFTAttributes;
    let nftAttributes;
    let owner;

    beforeEach(async function () {
        [owner] = await ethers.getSigners();
        NFTAttributes = await ethers.getContractFactory("NFTAttributes");
        nftAttributes = await NFTAttributes.deploy();
        await nftAttributes.deployed();
    });

    it("should set and get attributes correctly", async function () {
        const tokenId = 1;
        const names = ["Strength", "Agility"];
        const values = [500, 300];

        await nftAttributes.setAttributes(tokenId, names, values);
        const [retrievedNames, retrievedValues] = await nftAttributes.getAttributes(tokenId);

        expect(retrievedNames).to.deep.equal(names);
        expect(retrievedValues.map(v => v.toNumber())).to.deep.equal(values);
    });

    it("should delete attributes correctly", async function () {
        const tokenId = 1;
        const names = ["Strength", "Agility"];
        const values = [500, 300];

        await nftAttributes.setAttributes(tokenId, names, values);
        await nftAttributes.deleteAttributes(tokenId);
        const [retrievedNames, retrievedValues] = await nftAttributes.getAttributes(tokenId);

        expect(retrievedNames).to.deep.equal([]);
        expect(retrievedValues.map(v => v.toNumber())).to.deep.equal([]);
    });

    it("should calculate rarity correctly", async function () {
        const tokenId = 1;
        const names = ["Strength", "Agility"];
        const values = [500, 300];
        await nftAttributes.setAttributes(tokenId, names, values);
        const rarity = await nftAttributes["calculateRarity(uint256)"](tokenId);
        expect(rarity.toNumber()).to.be.greaterThan(0);
    });

    it("should deploy NFTAttributes contract successfully", async function () {
        expect(nftAttributes.address).to.match(/^0x[a-fA-F0-9]{40}$/);
    });
});
