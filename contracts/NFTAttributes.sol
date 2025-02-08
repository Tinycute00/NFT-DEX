// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BaseContract
 * @dev Base contract containing common functionality and attributes.
 */
contract BaseContract {
    // Common attribute: contract owner
    address public owner;

    // Event emitted when ownership is transferred
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Sets the deployer as the owner.
     */
    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), owner);
    }

    /**
     * @dev Modifier to restrict functions to the owner.
     */
    modifier onlyOwner() {
        require(owner == msg.sender, "Caller is not the owner");
        _;
    }

    /**
     * @dev Transfers contract ownership.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

/**
 * @title NFTAttributes
 * @dev Contract for handling NFT attributes and rarity calculation.
 */
contract NFTAttributes is BaseContract {
    // Constants
    uint256 public constant MAX_ATTRIBUTES = 20;     // Maximum number of attributes allowed
    uint256 public constant MAX_ATTRIBUTE_VALUE = 1000; // Maximum attribute value allowed
    
    // Structure for NFT attributes
    struct Attributes {
        uint256[] values;      // Array of attribute values
        string[] names;        // Array of attribute names
        uint256 count;         // Number of attributes
    }
    
    // Mapping to store attribute distribution
    mapping(string => mapping(uint256 => uint256)) private attributeDistribution;
    // NOTE: The current logic for attributeDistribution has not been fully validated,
    // and its effect on rarity calculation might be uncertain.
    // It is recommended to clarify or decouple the logic in future versions.

    // Mapping to store attributes for each NFT tokenId
    mapping(uint256 => Attributes) private attributesMap;

    /**
     * @dev Sets NFT attributes. Requires that attrNames and attrValues arrays have equal lengths.
     */
    function setAttributes(uint256 tokenId, string[] memory attrNames, uint256[] memory attrValues) external {
        require(attrNames.length == attrValues.length, "Arrays length mismatch");
        attributesMap[tokenId] = Attributes(attrValues, attrNames, attrNames.length);
    }

    /**
     * @dev Retrieves the NFT attributes.
     */
    function getAttributes(uint256 tokenId) external view returns (string[] memory, uint256[] memory) {
        Attributes storage attrs = attributesMap[tokenId];
        return (attrs.names, attrs.values);
    }

    /**
     * @dev Deletes the NFT attributes.
     */
    function deleteAttributes(uint256 tokenId) external {
        delete attributesMap[tokenId];
    }

    /**
     * @dev Calculates NFT rarity by summing the attribute values.
     */
    function calculateRarity(uint256 tokenId) external view returns (uint256) {
        Attributes storage attrs = attributesMap[tokenId];
        uint256 rarity = 0;
        for (uint256 i = 0; i < attrs.values.length; i++) {
            rarity += attrs.values[i];
        }
        return rarity;
    }
}