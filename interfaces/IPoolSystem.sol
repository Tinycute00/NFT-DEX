// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IPoolSystem {
    // Define function signatures as needed by SystemMarket
    function getPoolBalance() external view returns (uint256);

    // Added missing function updatePools to update the pool data
    function updatePools(uint256 amount, bool isSystemFee) external;

    // 添加其他必要的函数签名...
} 