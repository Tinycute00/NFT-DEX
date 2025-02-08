pragma solidity ^0.8.9;

library MarketLib {
    // Structure representing market pool data (excluding isActive property) corresponding to GalleryV1's market pools.
    struct MarketInfo {
        uint256 basePool;
        uint256 basePoolTotal;
        uint256 premiumPool;
    }

    uint256 internal constant BASE_POOL_RATE = 200;   // 20%
    uint256 internal constant PREMIUM_POOL_RATE = 200; // 20%
    uint256 internal constant SCALE = 1000;            // Scaling factor
    uint256 internal constant FEE_PERCENT = 10;         // Total system market fee percentage (10%)

    /**
     * @dev Updates the market pools.
     * @param m Reference to the market pool structure.
     * @param amount The amount to update.
     * @param isSystemFee Whether the update is due to a system fee (if true, splits the fee accordingly).
     */
    function updatePools(MarketInfo storage m, uint256 amount, bool isSystemFee) internal {
        if (isSystemFee) {
            uint256 baseAmount = (amount * BASE_POOL_RATE) / SCALE;
            uint256 premiumAmount = (amount * PREMIUM_POOL_RATE) / SCALE;
            m.basePool += baseAmount;
            m.basePoolTotal += baseAmount;
            m.premiumPool += premiumAmount;
        } else {
            m.basePool += amount;
            m.basePoolTotal += amount;
        }
    }

    /**
     * @dev Calculates the system market price based on basePrice, rarity, and the current premium pool.
     * @param basePrice The NFT's base price.
     * @param rarity The NFT's rarity.
     * @param premiumPool The current premium pool balance.
     * @return The calculated system market price.
     */
    function getSystemPrice(uint256 basePrice, uint256 rarity, uint256 premiumPool) internal pure returns (uint256) {
        if (premiumPool == 0) return basePrice;
        uint256 premium = (premiumPool * rarity) / 10000;
        return basePrice + premium;
    }

    /**
     * @dev Handles the system fee by splitting the total fee (10%) such that 8% goes to the premium pool and 2% to the platform.
     * @param currentPrice The current NFT price.
     * @param m Reference to the market pool to update the premium pool.
     * @param platformWallet The address to receive the platform fee.
     * @return fee The total calculated fee.
     */
    function handleSystemFee(uint256 currentPrice, MarketInfo storage m, address platformWallet) internal returns (uint256 fee) {
        fee = (currentPrice * FEE_PERCENT) / 100; // 10% fee
        uint256 premiumFee = (fee * 8) / 10;         // 8% goes to the premium pool
        uint256 platformFee = fee - premiumFee;      // Remaining 2% for the platform

        // Update the premium pool
        m.premiumPool += premiumFee;

        // Transfer platform fee to the platform wallet
        (bool success, ) = platformWallet.call{value: platformFee}("");
        require(success, "Transfer to platform wallet failed");

        return fee;
    }
} 