// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CreatorNFT1155Unlimited
 * @dev This contract is used to mint ERC1155 NFTs. It allows the creator to dynamically add component configurations,
 *      where each component's option rarity ranges from 1 to 100 and the supply limits are set by the creator.
 *      Once minting begins, the configuration is frozen and cannot be modified. It also emits events and
 *      provides interfaces for future NFT DEX integration.
 */
contract CreatorNFT1155Unlimited is ERC1155, Ownable {
    // Structure to define component configuration
    struct PartConfig {
        string partName;           // Component name
        uint256[] rarityForOption; // Rarity for each option (values between 1 and 100)
        uint256[] supplyLimit;     // Maximum supply for each option
        uint256[] mintedCount;     // Number minted for each option
    }

    // Dynamic storage for all component configurations
    PartConfig[] public parts;

    // Once minting begins, the configuration is frozen
    bool public configurationFrozen;

    // Auto-increment counter for tokenId
    uint256 public nextTokenId;

    // Structure to store NFT metadata: selected options for each component and overall rarity
    struct NFTMetadata {
        uint8[] selectedOptions; // Selected option index for each component
        uint256 overallRarity;   // Overall rarity
    }
    mapping(uint256 => NFTMetadata) public nftMetadata;

    event PartAdded(uint256 indexed partIndex, string partName);
    event ConfigurationFrozen();
    event NFTMinted(uint256 indexed tokenId, address indexed to, uint8[] selectedOptions, uint256 overallRarity);

    constructor(string memory uri) ERC1155(uri) {
        nextTokenId = 1;
        configurationFrozen = false;
    }

    /**
     * @dev Adds a new component configuration. Only callable by the owner and prior to configuration freeze.
     * @param _partName The component name.
     * @param _rarityForOption Array of rarity values for each option (each value between 1 and 100).
     * @param _supplyLimit Array of maximum supply values for each option.
     */
    function addPartConfig(
        string calldata _partName,
        uint256[] calldata _rarityForOption,
        uint256[] calldata _supplyLimit
    ) external onlyOwner {
        require(!configurationFrozen, "Configuration frozen");
        require(_rarityForOption.length == _supplyLimit.length, "Arrays length mismatch");
        uint256 len = _rarityForOption.length;
        for (uint256 i = 0; i < len; i++) {
            require(_rarityForOption[i] >= 1 && _rarityForOption[i] <= 100, "Rarity must be between 1 and 100");
        }
        // Initialize mintedCount array with zeros
        uint256[] memory zeros = new uint256[](len);
        PartConfig memory newPart = PartConfig({
            partName: _partName,
            rarityForOption: _rarityForOption,
            supplyLimit: _supplyLimit,
            mintedCount: zeros
        });
        parts.push(newPart);
        emit PartAdded(parts.length - 1, _partName);
    }

    /**
     * @dev Internal function to calculate overall rarity using a simple average.
     *      For example, if the selected rarities are [80, 40, 30, 10], then overall rarity = (80 + 40 + 30 + 10) / 4.
     */
    function _calculateOverallRarity(uint8[] memory selections) internal view returns (uint256) {
        require(selections.length == parts.length, "Selections length mismatch");
        uint256 sum = 0;
        for (uint256 i = 0; i < parts.length; i++) {
            uint8 optionIndex = selections[i];
            require(optionIndex < parts[i].rarityForOption.length, "Invalid selection for part");
            sum += parts[i].rarityForOption[optionIndex];
        }
        return sum / parts.length;
    }

    /**
     * @dev Mints an NFT. Only callable by the owner; freezes configuration upon the first mint.
     *      Users submit an array of selections representing the option index chosen for each component.
     * @param to The address to receive the NFT.
     * @param selections Array of selected option indices; length must match the number of components.
     * @return tokenId The tokenId of the minted NFT.
     */
    function mintNFT1155(address to, uint8[] calldata selections) external onlyOwner returns (uint256) {
        require(selections.length == parts.length, "Selections length mismatch");
        if (!configurationFrozen) {
            configurationFrozen = true;
            emit ConfigurationFrozen();
        }
        // Check that each component's selected option has available supply
        for (uint256 i = 0; i < parts.length; i++) {
            uint8 optionIndex = selections[i];
            require(optionIndex < parts[i].supplyLimit.length, "Invalid option index");
            require(parts[i].mintedCount[optionIndex] < parts[i].supplyLimit[optionIndex], "Selected option sold out");
        }
        uint256 overallRarity = _calculateOverallRarity(selections);
        // Update minted count for each component
        for (uint256 i = 0; i < parts.length; i++) {
            parts[i].mintedCount[selections[i]]++;
        }
        uint256 tokenId = nextTokenId;
        nextTokenId++;
        nftMetadata[tokenId] = NFTMetadata({
            selectedOptions: selections,
            overallRarity: overallRarity
        });
        // Mint the NFT (quantity is 1)
        _mint(to, tokenId, 1, "");
        emit NFTMinted(tokenId, to, selections, overallRarity);
        return tokenId;
    }
} 