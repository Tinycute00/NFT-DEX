// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BaseContract
 * @dev 基礎合約，包含通用功能和屬性
 */
contract BaseContract {
    // 通用屬性
    address public owner;

    // 通用事件
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev 設置合約擁有者為部署者
     */
    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), owner);
    }

    /**
     * @dev 修飾符，限制只有擁有者可以調用
     */
    modifier onlyOwner() {
        require(owner == msg.sender, "Caller is not the owner");
        _;
    }

    /**
     * @dev 轉移合約擁有權
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

/**
 * @title NFTAttributes
 * @dev 處理NFT屬性和稀有度計算的合約
 */
contract NFTAttributes is BaseContract {
    // 常量
    uint256 public constant MAX_ATTRIBUTES = 20;     // 增加最大屬性數量
    uint256 public constant MAX_ATTRIBUTE_VALUE = 1000; // 增加最大屬性值
    
    // 屬性結構體
    struct Attributes {
        uint256[] values;      // 屬性值數組
        string[] names;        // 屬性名稱數組
        uint256 count;         // 屬性數量
    }
    
    // 映射宣告，確保添加分號
    mapping(string => mapping(uint256 => uint256)) private attributeDistribution;
    // NOTE: 当前 attributeDistribution 的逻辑尚未经过详细验证，并且其在稀有度计算中的影响可能存在不确定性。
    // 建议在后续版本中明确属性加总、分布逻辑，或考虑将该逻辑进行解耦优化。

    // Mapping to store attributes for each tokenId
    mapping(uint256 => Attributes) private attributesMap;

    /**
     * @dev 設置 NFT 屬性，要求 attrNames 與 attrValues 長度一致
     */
    function setAttributes(uint256 tokenId, string[] memory attrNames, uint256[] memory attrValues) external {
        require(attrNames.length == attrValues.length, "Arrays length mismatch");
        attributesMap[tokenId] = Attributes(attrValues, attrNames, attrNames.length);
    }

    /**
     * @dev 獲取 NFT 屬性
     */
    function getAttributes(uint256 tokenId) external view returns (string[] memory, uint256[] memory) {
        Attributes storage attrs = attributesMap[tokenId];
        return (attrs.names, attrs.values);
    }

    /**
     * @dev 刪除 NFT 屬性
     */
    function deleteAttributes(uint256 tokenId) external {
        delete attributesMap[tokenId];
    }

    /**
     * @dev 計算 NFT 稀有度，這裡採用簡單的累加屬性值作為稀有度指標
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