// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/**
 * @title NFTMarket
 * @dev Contract handling NFT market trading logic.
 */
contract NFTMarket is ReentrancyGuardUpgradeable {
    // Market information structure
    struct MarketInfo {
        uint256 basePool;        // Base pool balance
        uint256 basePoolTotal;   // Total accumulated base pool
        uint256 premiumPool;     // Premium pool balance
        bool isActive;           // Whether the market is active
    }
    
    // NFT information structure
    struct NFTInfo {
        uint256 basePrice;      // Base price of NFT
        uint256 rarity;         // Rarity of NFT
        bool priceConfirmed;    // Whether the price is confirmed
        bool inSystemMarket;    // Whether the NFT is in the system market
    }
    
    // Constants
    uint256 private constant SYSTEM_FEE = 25;        // System fee (2.5%)
    uint256 private constant BASE_POOL_RATE = 200;   // Base pool rate (20%)
    uint256 private constant PREMIUM_POOL_RATE = 200; // Premium pool rate (20%)
    uint256 private constant SCALE = 1000;           // Scaling factor
    
    // Market state
    MarketInfo public marketInfo;
    
    // Events
    event SystemMarketTrade(uint256 indexed tokenId, address indexed trader, uint256 price, bool isBuy);
    event NFTSoldToSystem(uint256 indexed tokenId, address indexed seller, uint256 price);
    event PriceConfirmed(uint256 indexed tokenId, uint256 basePrice);
    event MarketStateChanged(bool isActive);
    event PoolUpdated(uint256 basePool, uint256 premiumPool);
    
    /**
     * @dev Calculates the system market price.
     */
    function getSystemPrice(uint256 basePrice, uint256 rarity) public view returns (uint256) {
        if (marketInfo.premiumPool == 0) return basePrice;
        
        uint256 maxPremium = (marketInfo.basePoolTotal * 45) / 100; // Maximum premium is 45% of the base pool
        uint256 availablePremium = marketInfo.premiumPool > maxPremium ? maxPremium : marketInfo.premiumPool;
        
        uint256 premium = (availablePremium * rarity) / 10000;
        return basePrice + premium;
    }
    
    /**
     * @dev Retrieves the market information.
     */
    function getMarketInfo() public view returns (MarketInfo memory) {
        return marketInfo;
    }
    
    /**
     * @dev Updates the market pools.
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
     * @dev Handles the system fee.
     */
    function _handleSystemFee(uint256 price) internal returns (uint256) {
        uint256 fee = (price * SYSTEM_FEE) / SCALE;
        _updatePools(fee, true);
        return fee;
    }
    
    /**
     * @dev Toggles the market state.
     */
    function toggleMarket() internal {
        marketInfo.isActive = !marketInfo.isActive;
        emit MarketStateChanged(marketInfo.isActive);
    }
}
