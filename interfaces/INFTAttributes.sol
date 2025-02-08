// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface INFTAttributes {
    /**
     * @dev Sets NFT attributes. Requires attrNames and attrValues to have equal lengths.
     */
    function setAttributes(uint256 tokenId, string[] memory attrNames, uint256[] memory attrValues) external;

    /**
     * @dev Retrieves the NFT attributes.
     */
    function getAttributes(uint256 tokenId) external view returns (string[] memory, uint256[] memory);

    /**
     * @dev Deletes the NFT attributes.
     */
    function deleteAttributes(uint256 tokenId) external;

    /**
     * @dev Calculates the NFT rarity based on tokenId.
     */
    function calculateRarity(uint256 tokenId) external view returns (uint256);
} 