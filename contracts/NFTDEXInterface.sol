// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @title NFTDEXInterface
 * @dev This interface reserves NFT exchange-related functions for future integration, including listing, canceling, purchasing NFTs, and querying listing info.
 */
interface NFTDEXInterface {
    /**
     * @dev Lists an NFT. tokenId is the NFT ID to be listed and price is the expected sale price (in wei).
     */
    function listNFT(uint256 tokenId, uint256 price) external;

    /**
     * @dev Cancels an NFT listing.
     */
    function cancelListing(uint256 tokenId) external;

    /**
     * @dev Purchases a listed NFT; the payable amount must be equal to or greater than the listed price.
     */
    function buyNFT(uint256 tokenId) external payable;

    /**
     * @dev Retrieves the listing information for an NFT, including the seller's address and price.
     */
    function getListing(uint256 tokenId) external view returns (address seller, uint256 price);
} 