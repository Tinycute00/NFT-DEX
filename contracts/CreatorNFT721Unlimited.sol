// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CreatorNFT721Unlimited
 * @dev This contract is used to mint ERC721 NFTs. It allows the creator to set the rarity and image URL.
 *      Once minting begins, the configuration is frozen and cannot be modified. It also emits events and
 *      provides interfaces for future NFT DEX integration.
 */
contract CreatorNFT721Unlimited is ERC721, Ownable {
    uint256 public nextTokenId;
    bool public configurationFrozen;

    struct NFTMetadata {
        uint256 rarity;  // NFT rarity (customizable from 1 to 100)
        string imageUrl; // Image URL
    }
    
    mapping(uint256 => NFTMetadata) public nftMetadata;

    event NFTMinted(uint256 indexed tokenId, address indexed to, uint256 rarity, string imageUrl);
    event ConfigurationFrozen();

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        nextTokenId = 1;
        configurationFrozen = false;
    }

    /**
     * @dev Mints an NFT. On the first mint, the configuration is frozen.
     * @param to The address that will receive the NFT.
     * @param rarity The rarity of the NFT (1~100).
     * @param imageUrl The URL of the NFT image.
     * @return tokenId The minted NFT tokenId.
     */
    function mintNFT(address to, uint256 rarity, string calldata imageUrl) external onlyOwner returns (uint256) {
        if (!configurationFrozen) {
            configurationFrozen = true;
            emit ConfigurationFrozen();
        }
        uint256 tokenId = nextTokenId;
        nextTokenId++;
        _mint(to, tokenId);
        nftMetadata[tokenId] = NFTMetadata({
            rarity: rarity,
            imageUrl: imageUrl
        });
        emit NFTMinted(tokenId, to, rarity, imageUrl);
        return tokenId;
    }
} 