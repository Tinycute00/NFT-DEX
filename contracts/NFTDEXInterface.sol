// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @title NFTDEXInterface
 * @dev 此接口預留 NFT 交易所相關功能接口供未來集成使用，包含上架、取消上架、購買 NFT、查詢上架資訊等。
 */
interface NFTDEXInterface {
    /**
     * @dev 上架 NFT，tokenId 為待上架的 NFT ID，price 為期望售價（單位 wei）。
     */
    function listNFT(uint256 tokenId, uint256 price) external;

    /**
     * @dev 取消 NFT 上架。
     */
    function cancelListing(uint256 tokenId) external;

    /**
     * @dev 購買上架的 NFT，應付金額須等於或大於上架售價。
     */
    function buyNFT(uint256 tokenId) external payable;

    /**
     * @dev 查詢上架 NFT 的信息，包括賣家地址和價格。
     */
    function getListing(uint256 tokenId) external view returns (address seller, uint256 price);
} 