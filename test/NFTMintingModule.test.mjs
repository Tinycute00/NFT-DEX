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
        
        // 部署相關合約
        const NFTAttributesFactory = await ethers.getContractFactory("NFTAttributes");
        const nftAttributes = await NFTAttributesFactory.deploy();
        await nftAttributes.deployed();

        const PoolSystemFactory = await ethers.getContractFactory("PoolSystem");
        const poolSystem = await PoolSystemFactory.deploy();
        await poolSystem.deployed();

        const DummyFLPFactory = await ethers.getContractFactory("MockFLP");
        const dummyFLP = await DummyFLPFactory.deploy();
        await dummyFLP.deployed();
        
        // 部署 NFTMintingModule 合約
        const NFTMintingModule = await ethers.getContractFactory("NFTMintingModule");
        nftMinting = await NFTMintingModule.deploy(nftAttributes.address, poolSystem.address, dummyFLP.address);
        await nftMinting.deployed();
        
        // 設置鑄造價格：Guarantee 階段
        await nftMinting.setPhasePrice(1, ethers.utils.parseEther("0.01"));
        
        // 使用最新區塊時間計算時間範圍
        const latestBlock = await ethers.provider.getBlock("latest");
        const currentTime = latestBlock.timestamp;
        const startTime = currentTime + 2000; // 2000秒後開始
        const endTime = startTime + 3600; // 持續1小時

        // 設置白名單
        await nftMinting.setWhitelistEntry(
            addr1.address,
            1, // phase
            5, // maxMint
            startTime,
            endTime
        );
    });

    describe("白名單管理", function () {
        it("只有擁有者可以設置白名單", async function () {
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
                throw new Error("應該失敗");
            } catch (err) {
                expect(err.message).to.contain("Ownable: caller is not the owner");
            }
        });

        it("可以批量設置白名單", async function () {
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

        it("可以移除白名單", async function () {
            await nftMinting.removeFromWhitelist(addr1.address);
            const info = await nftMinting.getWhitelistInfo(addr1.address);
            expect(info.phase).to.equal(0);
        });

        it("可以批量移除白名單", async function () {
            const addresses = [addr1.address, addr2.address];
            await nftMinting.removeFromWhitelistBatch(addresses);
            const info1 = await nftMinting.getWhitelistInfo(addr1.address);
            const info2 = await nftMinting.getWhitelistInfo(addr2.address);
            expect(info1.phase).to.equal(0);
            expect(info2.phase).to.equal(0);
        });
    });

    describe("NFT 鑄造", function () {
        it("應該自動遞增 tokenId", async function () {
            // 等待直到開始時間
            const info = await nftMinting.getWhitelistInfo(addr1.address);
            await ethers.provider.send("evm_setNextBlockTimestamp", [info.mintStartTime.toNumber() + 300]);
            await ethers.provider.send("evm_mine");

            const tx1 = await nftMinting.connect(addr1).mintGuarantee(10, "https://example.com/nft.png", { value: ethers.utils.parseEther("0.01") });
            const receipt1 = await tx1.wait();
            const firstTokenId = receipt1.events.find(e => e.event === "NFTCreated").args.tokenId;

            const tx2 = await nftMinting.connect(addr1).mintGuarantee(10, "https://example.com/nft.png", { value: ethers.utils.parseEther("0.01") });
            const receipt2 = await tx2.wait();
            const secondTokenId = receipt2.events.find(e => e.event === "NFTCreated").args.tokenId;
            
            expect(secondTokenId.toNumber()).to.equal(firstTokenId.toNumber() + 1);
        });

        it("不同階段應該使用正確的價格", async function () {
            const info = await nftMinting.getWhitelistInfo(addr1.address);
            await ethers.provider.send("evm_setNextBlockTimestamp", [info.mintStartTime.toNumber() + 300]);
            await ethers.provider.send("evm_mine");
            try {
                await nftMinting.connect(addr1).mintGuarantee(10, "https://example.com/nft.png", { value: ethers.utils.parseEther("0.1") });
                throw new Error("應該失敗");
            } catch (err) {
                expect(err.message).to.contain("Incorrect ETH value for Guarantee phase");
            }
        });

        it("超過最大鑄造數量應該失敗", async function () {
            const info = await nftMinting.getWhitelistInfo(addr1.address);
            await ethers.provider.send("evm_setNextBlockTimestamp", [info.mintStartTime.toNumber() + 300]);
            await ethers.provider.send("evm_mine");

            for (let i = 0; i < 5; i++) {
                await nftMinting.connect(addr1).mintGuarantee(10, "https://example.com/nft.png", { value: ethers.utils.parseEther("0.01") });
            }
            try {
                await nftMinting.connect(addr1).mintGuarantee(10, "https://example.com/nft.png", { value: ethers.utils.parseEther("0.01") });
                throw new Error("應該失敗");
            } catch (err) {
                expect(err.message).to.contain("Mint limit reached");
            }
        });

        it("非白名單地址不能鑄造", async function () {
            const info = await nftMinting.getWhitelistInfo(addr1.address);
            await ethers.provider.send("evm_setNextBlockTimestamp", [info.mintStartTime.toNumber() + 300]);
            await ethers.provider.send("evm_mine");
            try {
                await nftMinting.connect(addr2).mintGuarantee(10, "https://example.com/nft.png", { value: ethers.utils.parseEther("0.01") });
                throw new Error("應該失敗");
            } catch (err) {
                expect(err.message).to.contain("Address not whitelisted");
            }
        });

        it("在鑄造時間範圍外應該失敗", async function () {
            const info = await nftMinting.getWhitelistInfo(addr1.address);
            await ethers.provider.send("evm_setNextBlockTimestamp", [info.mintEndTime.toNumber() + 10]);
            await ethers.provider.send("evm_mine");
            try {
                await nftMinting.connect(addr1).mintGuarantee(10, "https://example.com/nft.png", { value: ethers.utils.parseEther("0.01") });
                throw new Error("應該失敗");
            } catch (err) {
                expect(err.message).to.contain("Not in minting period");
            }
        });

        it("應該批量鑄造 NFT 並更新白名單鑄造數量", async function () {
            // 假設 addr1 已在白名單中且允許鑄造數量較高，否則先設定
            // 例如這裡先用 setWhitelistEntry 設定 addr1 白名單（僅在測試環境下執行）
            const latestBlock = await ethers.provider.getBlock("latest");
            const currentTime = latestBlock.timestamp;
            const startTime = currentTime + 10;  // 10秒後開始
            const endTime = startTime + 3600;      // 持續1小時
            await nftMinting.connect(owner).setWhitelistEntry(addr1.address, 1, 10, startTime, endTime);

            // 設置保證階段鑄造價格
            await nftMinting.connect(owner).setPhasePrice(1, ethers.utils.parseEther("0.01"));

            // 模擬鑄造期間，將區塊時間設定在 minting 時間內
            await ethers.provider.send("evm_setNextBlockTimestamp", [startTime + 100]);
            await ethers.provider.send("evm_mine");

            // 定義兩個 NFT 的相關資料
            const rarities = [10, 20];
            const imageUrls = ["https://example.com/nft1.png", "https://example.com/nft2.png"];
            
            // 計算總支付額
            const phasePrice = await nftMinting.phasePrice(1);
            const totalCost = phasePrice.mul(rarities.length);

            // 取得當前白名單 minted 數量
            let whitelistBefore = await nftMinting.getWhitelistInfo(addr1.address);
            const mintedBefore = whitelistBefore.minted.toNumber();

            // 使用 addr1 進行批量鑄造
            const tx = await nftMinting.connect(addr1).batchMintGuarantee(rarities, imageUrls, { value: totalCost });
            const receipt = await tx.wait();

            // 檢查事件 NFTCreated 是否觸發兩次，並取得 tokenId
            const nftCreatedEvents = receipt.events.filter(e => e.event === "NFTCreated");
            expect(nftCreatedEvents.length).to.equal(2);
            const tokenIds = nftCreatedEvents.map(e => e.args.tokenId.toNumber());
            expect(tokenIds.length).to.equal(2);

            // 檢查白名單 minted 數量更新正確
            let whitelistAfter = await nftMinting.getWhitelistInfo(addr1.address);
            expect(whitelistAfter.minted.toNumber()).to.equal(mintedBefore + 2);
        });
    });
}); 