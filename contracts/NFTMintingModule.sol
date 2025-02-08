// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./CreatorNFT.sol";

/**
 * @title NFTMintingModule
 * @dev Independent minting contract inheriting from CreatorNFT. It includes minting entry points for four sale phases
 *      (Guarantee, First-Come-First-Serve, Public Sale, and Others). Once deployed, project addresses with whitelist settings
 *      can mint, achieving security isolation and gas optimization.
 */
contract NFTMintingModule is CreatorNFT {
    constructor(address _nftAttributes, address _poolSystem, address _flpContract)
        CreatorNFT(_nftAttributes, _poolSystem, _flpContract) {}

    // Guarantee Phase (phase == 1)
    function mintGuarantee(uint256 rarity, string memory imageUrl) external payable override returns (uint256) {
        WhitelistEntry storage entry = whitelistEntries[msg.sender];
        require(entry.maxMint > 0, "Address not whitelisted");
        require(entry.phase == 1, "Not authorized for Guarantee phase");
        require(block.timestamp >= entry.mintStartTime && block.timestamp <= entry.mintEndTime, "Not in minting period");
        require(entry.minted < entry.maxMint, "Mint limit reached");
        require(msg.value == phasePrice[1], "Incorrect ETH value for Guarantee phase");
        require(rarity > 0, "Invalid rarity");

        _tokenIdCounter++;
        uint256 newTokenId = _tokenIdCounter;

        uint256 weight = calculateWeight(rarity);
        nftInfo[newTokenId] = NFTInfo({
            nftType: NFTType.ERC721,
            rarity: rarity,
            weight: weight,
            imageUrl: imageUrl
        });
        
        _mintNFT(msg.sender, newTokenId);
        entry.minted += 1;
        emit NFTCreated(newTokenId, NFTType.ERC721, rarity, weight, imageUrl);
        
        return newTokenId;
    }

    // First-Come-First-Serve Phase (phase == 2)
    function mintFirstComeFirstServe(uint256 rarity, string memory imageUrl) external payable override returns (uint256) {
        WhitelistEntry storage entry = whitelistEntries[msg.sender];
        require(entry.maxMint > 0, "Address not whitelisted");
        require(entry.phase == 2, "Not authorized for First-Come-First-Serve phase");
        require(block.timestamp >= entry.mintStartTime && block.timestamp <= entry.mintEndTime, "Not in minting period");
        require(entry.minted < entry.maxMint, "Mint limit reached");
        require(msg.value == phasePrice[2], "Incorrect ETH value for First-Come-First-Serve phase");
        require(rarity > 0, "Invalid rarity");

        _tokenIdCounter++;
        uint256 newTokenId = _tokenIdCounter;

        uint256 weight = calculateWeight(rarity);
        nftInfo[newTokenId] = NFTInfo({
            nftType: NFTType.ERC721,
            rarity: rarity,
            weight: weight,
            imageUrl: imageUrl
        });
        _mintNFT(msg.sender, newTokenId);
        entry.minted += 1;
        emit NFTCreated(newTokenId, NFTType.ERC721, rarity, weight, imageUrl);
        
        return newTokenId;
    }

    // Public Sale Phase (phase == 3)
    function mintPublicSale(uint256 rarity, string memory imageUrl) external payable override returns (uint256) {
        WhitelistEntry storage entry = whitelistEntries[msg.sender];
        require(entry.maxMint > 0, "Address not whitelisted");
        require(entry.phase == 3, "Not authorized for Public Sale phase");
        require(block.timestamp >= entry.mintStartTime && block.timestamp <= entry.mintEndTime, "Not in minting period");
        require(entry.minted < entry.maxMint, "Mint limit reached");
        require(msg.value == phasePrice[3], "Incorrect ETH value for Public Sale phase");
        require(rarity > 0, "Invalid rarity");

        _tokenIdCounter++;
        uint256 newTokenId = _tokenIdCounter;

        uint256 weight = calculateWeight(rarity);
        nftInfo[newTokenId] = NFTInfo({
            nftType: NFTType.ERC721,
            rarity: rarity,
            weight: weight,
            imageUrl: imageUrl
        });
        _mintNFT(msg.sender, newTokenId);
        entry.minted += 1;
        emit NFTCreated(newTokenId, NFTType.ERC721, rarity, weight, imageUrl);
        
        return newTokenId;
    }

    // Other Phase (phase == 4)
    function mintOther(uint256 rarity, string memory imageUrl) external payable override returns (uint256) {
        WhitelistEntry storage entry = whitelistEntries[msg.sender];
        require(entry.maxMint > 0, "Address not whitelisted");
        require(entry.phase == 4, "Not authorized for Other phase");
        require(block.timestamp >= entry.mintStartTime && block.timestamp <= entry.mintEndTime, "Not in minting period");
        require(entry.minted < entry.maxMint, "Mint limit reached");
        require(msg.value == phasePrice[4], "Incorrect ETH value for Other phase");
        require(rarity > 0, "Invalid rarity");

        _tokenIdCounter++;
        uint256 newTokenId = _tokenIdCounter;

        uint256 weight = calculateWeight(rarity);
        nftInfo[newTokenId] = NFTInfo({
            nftType: NFTType.ERC721,
            rarity: rarity,
            weight: weight,
            imageUrl: imageUrl
        });
        _mintNFT(msg.sender, newTokenId);
        entry.minted += 1;
        emit NFTCreated(newTokenId, NFTType.ERC721, rarity, weight, imageUrl);
        
        return newTokenId;
    }

    // Batch mint NFTs during the Guarantee phase; allows a whitelisted address to mint multiple NFTs at once, subject to the whitelist maxMint.
    function batchMintGuarantee(uint256[] memory rarities, string[] memory imageUrls) external payable returns (uint256[] memory) {
        require(rarities.length == imageUrls.length, "Arrays length mismatch");
        uint256 count = rarities.length;
        WhitelistEntry storage entry = whitelistEntries[msg.sender];
        require(entry.maxMint > 0, "Address not whitelisted");
        require(entry.phase == 1, "Not authorized for Guarantee phase");
        require(block.timestamp >= entry.mintStartTime && block.timestamp <= entry.mintEndTime, "Not in minting period");
        require(entry.minted + count <= entry.maxMint, "Mint limit exceeded");
        require(msg.value == phasePrice[1] * count, "Incorrect ETH value for batch Guarantee phase");
        
        uint256[] memory newTokenIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
             require(rarities[i] > 0, "Invalid rarity");
             _tokenIdCounter++;
             uint256 newTokenId = _tokenIdCounter;
             newTokenIds[i] = newTokenId;
             uint256 weight = calculateWeight(rarities[i]);
             nftInfo[newTokenId] = NFTInfo({
                 nftType: NFTType.ERC721,
                 rarity: rarities[i],
                 weight: weight,
                 imageUrl: imageUrls[i]
             });
             _mintNFT(msg.sender, newTokenId);
             entry.minted += 1;
             emit NFTCreated(newTokenId, NFTType.ERC721, rarities[i], weight, imageUrls[i]);
        }
        return newTokenIds;
    }
} 