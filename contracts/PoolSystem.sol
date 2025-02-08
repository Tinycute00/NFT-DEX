// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

contract PoolSystem is Ownable {
    // 市場信息結構體
    struct MarketInfo {
        uint256 basePool;        // 基礎池餘額
        uint256 basePoolTotal;   // 基礎池累計總額
        uint256 premiumPool;     // 溢價池餘額
    }

    // 常量
    uint256 private constant BASE_POOL_RATE = 200;   // 基礎池比率 (20%)
    uint256 private constant PREMIUM_POOL_RATE = 200; // 溢價池比率 (20%)
    uint256 private constant PROJECT_INCOME_RATE = 100; // 項目收入比率 (10%)
    uint256 private constant SCALE = 1000;           // 比例基數

    // 市場狀態
    MarketInfo public marketInfo;

    // 事件
    event PoolUpdated(uint256 basePool, uint256 premiumPool);

    /**
     * @dev 更新市場池
     */
    function updatePools(uint256 amount, bool isSystemFee) external {
        if (isSystemFee) {
            uint256 premiumAmount = (amount * PREMIUM_POOL_RATE) / SCALE;
            uint256 projectIncome = (amount * PROJECT_INCOME_RATE) / SCALE;

            marketInfo.premiumPool += premiumAmount;
            // 假設項目收入的處理邏輯在這裡
            // 例如：將項目收入轉移到項目地址
            // (bool success, ) = payable(projectAddress).call{value: projectIncome}("");
            // require(success, "Transfer failed");

            emit PoolUpdated(marketInfo.basePool, marketInfo.premiumPool);
        } else {
            marketInfo.basePool += amount;
            marketInfo.basePoolTotal += amount;
            emit PoolUpdated(marketInfo.basePool, marketInfo.premiumPool);
        }
    }

    /**
     * @dev 獲取市場信息
     */
    function getMarketInfo() external view returns (MarketInfo memory) {
        return marketInfo;
    }
}
