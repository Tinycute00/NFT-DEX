pragma solidity ^0.8.9;

library MarketLib {
    // 市場池結構，對應 GalleryV1 中的市場池數據（不含 isActive 屬性）
    struct MarketInfo {
        uint256 basePool;
        uint256 basePoolTotal;
        uint256 premiumPool;
    }

    uint256 internal constant BASE_POOL_RATE = 200;   // 20%
    uint256 internal constant PREMIUM_POOL_RATE = 200; // 20%
    uint256 internal constant SCALE = 1000;            // 比例基數
    uint256 internal constant FEE_PERCENT = 10;         // 系統市場總手續費百分比（10%）

    /**
     * @dev 更新市場池的值。
     * @param m 市場池引用
     * @param amount 需要更新的金額
     * @param isSystemFee 是否為系統費用（若是，按比例拆分更新）
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
     * @dev 根據基礎價格、稀有度和當前溢價池計算系統市場價格
     * @param basePrice NFT 的基礎價格
     * @param rarity NFT 的稀有度
     * @param premiumPool 當前溢價池餘額
     * @return 計算出的系統市場價格
     */
    function getSystemPrice(uint256 basePrice, uint256 rarity, uint256 premiumPool) internal pure returns (uint256) {
        if (premiumPool == 0) return basePrice;
        uint256 premium = (premiumPool * rarity) / 10000;
        return basePrice + premium;
    }

    /**
     * @dev 處理系統市場手續費，把總手續費 (10%) 按 8% 進入溢價池和 2% 給平台收益進行分配。
     * @param currentPrice NFT 的當前價格
     * @param m 市場池引用，用於更新溢價池
     * @param platformWallet 平台收益接收地址
     * @return fee 計算出的總手續費
     */
    function handleSystemFee(uint256 currentPrice, MarketInfo storage m, address platformWallet) internal returns (uint256 fee) {
        fee = (currentPrice * FEE_PERCENT) / 100; // 10% 手續費
        uint256 premiumFee = (fee * 8) / 10;         // 8% 進入溢價池
        uint256 platformFee = fee - premiumFee;      // 剩餘 2% 給平台

        // 更新溢價池
        m.premiumPool += premiumFee;

        // 轉移平台收益
        (bool success, ) = platformWallet.call{value: platformFee}("");
        require(success, "Transfer to platform wallet failed");

        return fee;
    }
} 