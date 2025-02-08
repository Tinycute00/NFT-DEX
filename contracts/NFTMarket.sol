// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/**
 * @title NFTMarket
 * @dev 處理NFT市場交易邏輯的合約
 */
contract NFTMarket is ReentrancyGuardUpgradeable {
    // 市場信息結構體
    struct MarketInfo {
        uint256 basePool;        // 基礎池餘額
        uint256 basePoolTotal;   // 基礎池累計總額
        uint256 premiumPool;     // 溢價池餘額
        bool isActive;           // 市場是否活躍
    }
    
    // NFT信息結構體
    struct NFTInfo {
        uint256 basePrice;      // 基礎價格
        uint256 rarity;         // 稀有度
        bool priceConfirmed;    // 價格是否確認
        bool inSystemMarket;    // 是否在系統市場中
    }
    
    // 常量
    uint256 private constant SYSTEM_FEE = 25;        // 系統費用 (2.5%)
    uint256 private constant BASE_POOL_RATE = 200;   // 基礎池比率 (20%)
    uint256 private constant PREMIUM_POOL_RATE = 200; // 溢價池比率 (20%)
    uint256 private constant SCALE = 1000;           // 比例基數
    
    // 市場狀態
    MarketInfo public marketInfo;
    
    // 事件
    event SystemMarketTrade(uint256 indexed tokenId, address indexed trader, uint256 price, bool isBuy);
    event NFTSoldToSystem(uint256 indexed tokenId, address indexed seller, uint256 price);
    event PriceConfirmed(uint256 indexed tokenId, uint256 basePrice);
    event MarketStateChanged(bool isActive);
    event PoolUpdated(uint256 basePool, uint256 premiumPool);
    
    /**
     * @dev 計算系統市場價格
     */
    function getSystemPrice(uint256 basePrice, uint256 rarity) public view returns (uint256) {
        if (marketInfo.premiumPool == 0) return basePrice;
        
        uint256 maxPremium = (marketInfo.basePoolTotal * 45) / 100; // 最大溢價為基礎池的45%
        uint256 availablePremium = marketInfo.premiumPool > maxPremium ? maxPremium : marketInfo.premiumPool;
        
        uint256 premium = (availablePremium * rarity) / 10000;
        return basePrice + premium;
    }
    
    /**
     * @dev 獲取市場信息
     */
    function getMarketInfo() public view returns (MarketInfo memory) {
        return marketInfo;
    }
    
    /**
     * @dev 更新市場池
     */
    function _updatePools(uint256 amount, bool isSystemFee) internal {
        if (isSystemFee) {
            uint256 baseAmount = (amount * BASE_POOL_RATE) / SCALE;
            uint256 premiumAmount = (amount * PREMIUM_POOL_RATE) / SCALE;
            
            marketInfo.basePool += baseAmount;
            marketInfo.basePoolTotal += baseAmount;
            marketInfo.premiumPool += premiumAmount;
            
            emit PoolUpdated(marketInfo.basePool, marketInfo.premiumPool);
        } else {
            marketInfo.basePool += amount;
            marketInfo.basePoolTotal += amount;
            emit PoolUpdated(marketInfo.basePool, marketInfo.premiumPool);
        }
    }
    
    /**
     * @dev 處理系統費用
     */
    function _handleSystemFee(uint256 price) internal returns (uint256) {
        uint256 fee = (price * SYSTEM_FEE) / SCALE;
        _updatePools(fee, true);
        return fee;
    }
    
    /**
     * @dev 切換市場狀態
     */
    function toggleMarket() internal {
        marketInfo.isActive = !marketInfo.isActive;
        emit MarketStateChanged(marketInfo.isActive);
    }
}
