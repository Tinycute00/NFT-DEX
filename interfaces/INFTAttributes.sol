// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface INFTAttributes {
    /**
     * @dev 設置 NFT 屬性，要求 attrNames 與 attrValues 長度一致
     */
    function setAttributes(uint256 tokenId, string[] memory attrNames, uint256[] memory attrValues) external;

    /**
     * @dev 獲取 NFT 屬性
     */
    function getAttributes(uint256 tokenId) external view returns (string[] memory, uint256[] memory);

    /**
     * @dev 刪除 NFT 屬性
     */
    function deleteAttributes(uint256 tokenId) external;

    /**
     * @dev 根據 tokenId 計算 NFT 稀有度
     */
    function calculateRarity(uint256 tokenId) external view returns (uint256);
} 