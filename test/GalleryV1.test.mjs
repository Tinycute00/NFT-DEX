import { expect } from "chai";
import pkg from "hardhat";
const { ethers } = pkg;

describe("GalleryV1", function () {
    let GalleryV1;
    let galleryV1;
    let owner;

    beforeEach(async function () {
        [owner] = await ethers.getSigners();
        GalleryV1 = await ethers.getContractFactory("GalleryV1");
        galleryV1 = await GalleryV1.deploy();
        await galleryV1.deployed();
    });

    it("should initialize project correctly", async function () {
        const maxSupply = 100;
        const totalValue = ethers.utils.parseEther("10");

        await galleryV1.initializeProject(maxSupply, totalValue);
        const projectInfo = await galleryV1.projectInfo();

        expect(projectInfo.creator).to.equal(owner.address);
        expect(projectInfo.maxSupply.toNumber()).to.equal(maxSupply);
        expect(projectInfo.totalValue.toString()).to.equal(totalValue.toString());
    });

    it("should mint NFT correctly", async function () {
        const maxSupply = 100;
        const totalValue = ethers.utils.parseEther("10");

        await galleryV1.initializeProject(maxSupply, totalValue);
        await galleryV1.mint(owner.address);
        const totalMinted = (await galleryV1.projectInfo()).totalMinted.toNumber();

        expect(totalMinted).to.equal(1);
    });

    it("should set attributes correctly", async function () {
        const maxSupply = 100;
        const totalValue = ethers.utils.parseEther("10");
        const tokenId = 1;
        const names = ["Strength", "Agility"];
        const values = [500, 300];

        await galleryV1.initializeProject(maxSupply, totalValue);
        await galleryV1.mint(owner.address);
        await galleryV1.setAttributes(tokenId, names, values);
        const [retrievedNames, retrievedValues] = await galleryV1.getAttributes(tokenId);

        expect(retrievedNames).to.deep.equal(names);
        expect(retrievedValues.map(v => v.toNumber())).to.deep.equal(values);
    });

    it("should mint NFTs correctly", async function () {
        const maxSupply = 100;
        const totalValue = ethers.utils.parseEther("10");

        await galleryV1.initializeProject(maxSupply, totalValue);
        await galleryV1.mint(owner.address);
        await galleryV1.mint(owner.address);
        await galleryV1.mint(owner.address);

        const projectInfo = await galleryV1.projectInfo();
        expect(projectInfo.totalMinted.toNumber()).to.equal(3);
    });
});