import "@nomicfoundation/hardhat-chai-matchers";
import { expect } from "chai";
import pkg from "hardhat";
const { ethers } = pkg;

describe("NFTMintingModule", function () {
    this.timeout(200000);
    let nftMinting;
    let owner;
    let addr1;
    let addr2;
    let addrs;

    beforeEach(async function () {
        [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
        
        // Deploy related contracts
        const NFTAttributesFactory = await ethers.getContractFactory("NFTAttributes");
        const nftAttributes = await NFTAttributesFactory.deploy();
        await nftAttributes.deployed();

        const PoolSystemFactory = await ethers.getContractFactory("PoolSystem");
        const poolSystem = await PoolSystemFactory.deploy();
        await poolSystem.deployed();

        const DummyFLPFactory = await ethers.getContractFactory("MockFLP");
        const dummyFLP = await DummyFLPFactory.deploy();
        await dummyFLP.deployed();
        
        // Deploy the NFTMintingModule contract
        const NFTMintingModule = await ethers.getContractFactory("NFTMintingModule");
        nftMinting = await NFTMintingModule.deploy(nftAttributes.address, poolSystem.address, dummyFLP.address);
        await nftMinting.deployed();
        
        // Set the minting price for the Guarantee phase
        await nftMinting.setPhasePrice(1, ethers.utils.parseEther("0.01"));
        
        // Use the latest block time to determine the time range
        const latestBlock = await ethers.provider.getBlock("latest");
        const currentTime = latestBlock.timestamp;
        const startTime = currentTime + 2000; // starts in 2000 seconds
        const endTime = startTime + 3600; // lasts 1 hour

        // Set whitelist entry for addr1
        await nftMinting.setWhitelistEntry(
            addr1.address,
            1, // phase
            5, // maxMint
            startTime,
            endTime
        );
    });

    describe("Whitelist Management", function () {
        it("Only the owner can set whitelist entry", async function () {
            const startTime = Math.floor(Date.now() / 1000) + 100;
            const endTime = startTime + 3600;
            try {
                await nftMinting.connect(addr1).setWhitelistEntry(
                    addr2.address,
                    1,
                    5,
                    startTime,
                    endTime
                );
                throw new Error("Should have failed");
            } catch (err) {
                expect(err.message).to.contain("Ownable: caller is not the owner");
            }
        });

        it("Should allow batch whitelist setting", async function () {
            const startTime = Math.floor(Date.now() / 1000) + 100;
            const endTime = startTime + 3600;
            const addresses = [addr1.address, addr2.address];
            const phases = [1, 2];
            const maxMints = [5, 3];
            const startTimes = [startTime, startTime];
            const endTimes = [endTime, endTime];

            await nftMinting.setWhitelistEntries(
                addresses,
                phases,
                maxMints,
                startTimes,
                endTimes
            );

            const info1 = await nftMinting.getWhitelistInfo(addr1.address);
            const info2 = await nftMinting.getWhitelistInfo(addr2.address);

            expect(info1.phase).to.equal(1);
            expect(info1.maxMint.toNumber()).to.equal(5);
            expect(info2.phase).to.equal(2);
            expect(info2.maxMint.toNumber()).to.equal(3);
        });

        it("Should fail if incorrect ETH value is sent", async function () {
            const info = await nftMinting.getWhitelistInfo(addr1.address);
            await ethers.provider.send("evm_setNextBlockTimestamp", [info.mintStartTime.toNumber() + 300]);
            await ethers.provider.send("evm_mine");
            try {
                await nftMinting.connect(addr1).mintGuarantee(10, "https://example.com/nft.png", { value: ethers.utils.parseEther("0.1") });
                throw new Error("Should have failed");
            } catch (err) {
                expect(err.message).to.contain("Incorrect ETH value for Guarantee phase");
            }
        });

        it("Should fail if mint limit is exceeded", async function () {
            const info = await nftMinting.getWhitelistInfo(addr1.address);
            await ethers.provider.send("evm_setNextBlockTimestamp", [info.mintStartTime.toNumber() + 300]);
            await ethers.provider.send("evm_mine");

            for (let i = 0; i < 5; i++) {
                await nftMinting.connect(addr1).mintGuarantee(10, "https://example.com/nft.png", { value: ethers.utils.parseEther("0.01") });
            }
            try {
                await nftMinting.connect(addr1).mintGuarantee(10, "https://example.com/nft.png", { value: ethers.utils.parseEther("0.01") });
                throw new Error("Should have failed");
            } catch (err) {
                expect(err.message).to.contain("Mint limit reached");
            }
        });

        it("Non-whitelisted address should not be able to mint", async function () {
            const info = await nftMinting.getWhitelistInfo(addr1.address);
            await ethers.provider.send("evm_setNextBlockTimestamp", [info.mintStartTime.toNumber() + 300]);
            await ethers.provider.send("evm_mine");
            try {
                await nftMinting.connect(addr2).mintGuarantee(10, "https://example.com/nft.png", { value: ethers.utils.parseEther("0.01") });
                throw new Error("Should have failed");
            } catch (err) {
                expect(err.message).to.contain("Address not whitelisted");
            }
        });

        it("Should fail to mint outside the allowed minting period", async function () {
            const info = await nftMinting.getWhitelistInfo(addr1.address);
            await ethers.provider.send("evm_setNextBlockTimestamp", [info.mintEndTime.toNumber() + 10]);
            await ethers.provider.send("evm_mine");
            try {
                await nftMinting.connect(addr1).mintGuarantee(10, "https://example.com/nft.png", { value: ethers.utils.parseEther("0.01") });
                throw new Error("Should have failed");
            } catch (err) {
                expect(err.message).to.contain("Not in minting period");
            }
        });

        it("Should batch mint NFTs and update the whitelist minted count", async function () {
            // For testing, set whitelist entry for addr1 if not already set high
            const latestBlock = await ethers.provider.getBlock("latest");
            const currentTime = latestBlock.timestamp;
            const startTime = currentTime + 10;  // starts in 10 seconds
            const endTime = startTime + 3600;      // lasts 1 hour
            await nftMinting.connect(owner).setWhitelistEntry(addr1.address, 1, 10, startTime, endTime);

            // Set the minting price for Guarantee phase
            await nftMinting.connect(owner).setPhasePrice(1, ethers.utils.parseEther("0.01"));

            // Simulate being in the minting period
            await ethers.provider.send("evm_setNextBlockTimestamp", [startTime + 100]);
            await ethers.provider.send("evm_mine");

            // Data for two NFTs
            const rarities = [10, 20];
            const imageUrls = ["https://example.com/nft1.png", "https://example.com/nft2.png"];
            
            // Calculate total cost
            const phasePrice = await nftMinting.phasePrice(1);
            const totalCost = phasePrice.mul(rarities.length);

            // Get the current whitelist minted count
            let whitelistBefore = await nftMinting.getWhitelistInfo(addr1.address);
            const mintedBefore = whitelistBefore.minted.toNumber();

            // Batch mint NFTs using addr1
            const tx = await nftMinting.connect(addr1).batchMintGuarantee(rarities, imageUrls, { value: totalCost });
            const receipt = await tx.wait();

            // Check that the NFTCreated event was emitted twice and retrieve tokenIds
            const nftCreatedEvents = receipt.events.filter(e => e.event === "NFTCreated");
            expect(nftCreatedEvents.length).to.equal(2);
            const tokenIds = nftCreatedEvents.map(e => e.args.tokenId.toNumber());
            expect(tokenIds.length).to.equal(2);

            // Verify that the whitelist minted count has been updated correctly
            let whitelistAfter = await nftMinting.getWhitelistInfo(addr1.address);
            expect(whitelistAfter.minted.toNumber()).to.equal(mintedBefore + 2);
        });
    });
}); 