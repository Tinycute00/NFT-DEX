// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CreatorNFT721Unlimited
 * @dev 此合約用於鑄造 ERC721 NFT，支持創作者直接設定 NFT 的稀有度與圖片地址，
 *      鑄造開始後凍結配置，不允許再調整。並預留事件與接口供未來 NFT DEX 集成。
 */
contract CreatorNFT721Unlimited is ERC721, Ownable {
    uint256 public nextTokenId;
    bool public configurationFrozen;

    struct NFTMetadata {
        uint256 rarity;  // NFT 稀有度（1~100可自定義）
        string imageUrl; // 圖片URL
    }
    
    mapping(uint256 => NFTMetadata) public nftMetadata;

    event NFTMinted(uint256 indexed tokenId, address indexed to, uint256 rarity, string imageUrl);
    event ConfigurationFrozen();

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        nextTokenId = 1;
        configurationFrozen = false;
    }

    /**
     * @dev 鑄造 NFT。鑄造開始後，配置凍結，
     *      NFT 的稀有度和圖片地址由創作者直接設定。
     * @param to 接收 NFT 的地址
     * @param rarity NFT 稀有度（1~100）
     * @param imageUrl NFT 圖片的URL
     * @return tokenId 鑄造出的 NFT tokenId
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