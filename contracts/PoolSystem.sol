// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

contract PoolSystem is Ownable {
    // Market information structure
    struct MarketInfo {
        uint256 basePool;        // Base pool balance
        uint256 basePoolTotal;   // Total accumulated base pool
        uint256 premiumPool;     // Premium pool balance
    }

    // Constants
    uint256 private constant BASE_POOL_RATE = 200;   // Base pool rate (20%)
    uint256 private constant PREMIUM_POOL_RATE = 200; // Premium pool rate (20%)
    uint256 private constant PROJECT_INCOME_RATE = 100; // Project income rate (10%)
    uint256 private constant SCALE = 1000;            // Scaling factor

    // Market state
    MarketInfo public marketInfo;

    // Event emitted when the pool is updated
    event PoolUpdated(uint256 basePool, uint256 premiumPool);

    /**
     * @dev Updates the market pools.
     */
    function updatePools(uint256 amount, bool isSystemFee) external {
        if (isSystemFee) {
            uint256 premiumAmount = (amount * PREMIUM_POOL_RATE) / SCALE;
            uint256 projectIncome = (amount * PROJECT_INCOME_RATE) / SCALE;

            marketInfo.premiumPool += premiumAmount;
            // Assume project income handling occurs here, e.g. transferring to a project address.
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
     * @dev Retrieves the current market information.
     */
    function getMarketInfo() external view returns (MarketInfo memory) {
        return marketInfo;
    }
}
