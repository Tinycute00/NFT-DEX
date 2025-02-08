// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./NFTDEXInterface.sol";
import "./interfaces/IFLPContract.sol";
import "./interfaces/IPoolSystem.sol";
import "./MarketLib.sol";

/**
 * @title NFTDEXCore
 * @dev 此合約作為 NFT DEX 的核心，提供市場訂單功能以及雙池和 FLP 機制。
 *      雙池機制保證 NFT 的最低價格，並根據 NFT 的稀有度與權重來決定額外溢價。
 *      FLP 機制用於在交易過程中鑄造 FLP 代幣並更新池子狀態。
 */
contract NFTDEXCore is NFTDEXInterface, Ownable {

    // --------------------------
    // 市場訂單部分
    // --------------------------

    struct Listing {
        address seller;
        uint256 price;
    }

    // 映射 tokenId 到訂單
    mapping(uint256 => Listing) public listings;

    // 事件 (市場訂單相關)
    event NFTListed(uint256 indexed tokenId, uint256 price);
    event NFTCanceled(uint256 indexed tokenId);
    event NFTBought(uint256 indexed tokenId, address indexed buyer, uint256 price);

    // --------------------------
    // FLP 機制相關
    // --------------------------

    IFLPContract public flpContract;
    IPoolSystem public poolSystem;

    MarketLib.MarketInfo public marketInfo;

    // 新增平台費地址，用於接收平台收益（1%的費用）
    address public platformFeeAddress;

    function setPlatformFeeAddress(address _addr) external onlyOwner {
        require(_addr != address(0), "Platform fee address not set");
        platformFeeAddress = _addr;
    }

    function setFLPContract(address flpAddress) external onlyOwner {
        flpContract = IFLPContract(flpAddress);
    }

    function setPoolSystem(address poolSystemAddress) external onlyOwner {
        poolSystem = IPoolSystem(poolSystemAddress);
    }

    // 內部函數: 鑄造 FLP 代幣，同時計算額外費用並更新池子 (額外費用 = (weight * 10) / 100)
    function _mintFLP(address to, uint256 weight) internal returns (uint256) {
        uint256 flpTokenId = flpContract.totalSupply() + 1;
        flpContract.mint(to, flpTokenId, 0, 0, 0);
        uint256 extraFee = (weight * 10) / 100;
        poolSystem.updatePools(extraFee, true);
        return flpTokenId;
    }

    // --------------------------
    // 市場訂單功能的實現
    // --------------------------

    function listNFT(uint256 tokenId, uint256 price) external override {
        listings[tokenId] = Listing({ seller: msg.sender, price: price });
        emit NFTListed(tokenId, price);
    }

    function cancelListing(uint256 tokenId) external override {
        Listing memory listing = listings[tokenId];
        require(listing.seller == msg.sender, "Not the seller");
        delete listings[tokenId];
        emit NFTCanceled(tokenId);
    }

    function buyNFT(uint256 tokenId) external payable override {
        Listing memory listing = listings[tokenId];
        require(listing.seller != address(0), "NFT not listed");
        require(msg.value >= listing.price, "Insufficient payment");
        require(platformFeeAddress != address(0), "Platform fee address not set");

        // 計算 3% 手續費
        uint256 fee = (listing.price * 3) / 100;
        uint256 sellerAmount = listing.price - fee;
        uint256 platformFee = (listing.price * 1) / 100; // 1% 給平台
        uint256 poolFee = (listing.price * 2) / 100;     // 2% 更新溢價池

        // 將金額轉給賣家（扣除 3% 手續費）
        payable(listing.seller).transfer(sellerAmount);
        // 將平台費轉給設定的平台費地址
        payable(platformFeeAddress).transfer(platformFee);

        // 新增：確認 poolSystem 為一個部署了程式碼的合約
        require(address(poolSystem).code.length > 0, "PoolSystem is not a contract");

        // 更新池子，將 2% 手續費加入溢價池
        poolSystem.updatePools(poolFee, true);

        // 如果有多餘的ETH，退回給買家
        uint256 refund = msg.value - listing.price;
        if (refund > 0) {
            payable(msg.sender).transfer(refund);
        }

        delete listings[tokenId];
        emit NFTBought(tokenId, msg.sender, listing.price);
    }

    function getListing(uint256 tokenId) external view override returns (address seller, uint256 price) {
        Listing memory listing = listings[tokenId];
        return (listing.seller, listing.price);
    }

    // 使用 MarketLib 計算系統市場價格
    function calculateSystemPrice(uint256 basePrice, uint256 rarity) external view returns (uint256) {
        return MarketLib.getSystemPrice(basePrice, rarity, marketInfo.premiumPool);
    }

    // 使用 MarketLib 處理系統市場手續費
    function handleSystemFee(uint256 currentPrice, address platformWallet) external returns (uint256) {
        return MarketLib.handleSystemFee(currentPrice, marketInfo, platformWallet);
    }
} 