// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IPoolSystem {
    // Returns the current pool balance
    function getPoolBalance() external view returns (uint256);

    // Added: Updates the pools with the given amount and fee type
    function updatePools(uint256 amount, bool isSystemFee) external;

    // Add other necessary function signatures...
} 