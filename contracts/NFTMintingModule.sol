// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./CreatorNFT.sol";

/**
 * @title NFTMintingModule
 * @dev 獨立鑄造合約，繼承自CreatorNFT，包含四個銷售階段(保證、先搶先贏、公售、其他)的鑄造入口
 * 此合約獨立部署後，可供項目方通過白名單設定後的地址進行鑄造，達到安全隔離效果，同時考慮到gas消耗的優化。
 */
contract NFTMintingModule is CreatorNFT {
    constructor(address _nftAttributes, address _poolSystem, address _flpContract)
        CreatorNFT(_nftAttributes, _poolSystem, _flpContract) {}

    // 保證階段 (phase == 1)
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

    // 先搶先贏階段 (phase == 2)
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

    // 公售階段 (phase == 3)
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

    // 其他階段 (phase == 4)
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

    // 批量保證階段鑄造 NFT，可讓白名單地址一次鑄造多個，受限於 whitelistEntries 中的 maxMint 設置
    function batchMintGuarantee(uint256[] memory rarities, string[] memory imageUrls) external payable returns (uint256[] memory) {
        require(rarities.length == imageUrls.length, "Arrays length mismatch");
        uint256 count = rarities.length;
        WhitelistEntry storage entry = whitelistEntries[msg.sender];
        require(entry.maxMint > 0, "Address not whitelisted");
        require(entry.phase == 1, "Not authorized for Guarantee phase");
        require(block.timestamp >= entry.mintStartTime && block.timestamp <= entry.mintEndTime, "Not in minting period");
        require(entry.minted + count <= entry.maxMint, "Mint limit exceeded");
        require(msg.value == phasePrice[1] * count, "Incorrect ETH value for batch guarantee phase");
        
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