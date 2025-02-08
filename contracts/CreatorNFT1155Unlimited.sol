// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CreatorNFT1155Unlimited
 * @dev 此合約用於鑄造 ERC1155 NFT，支持創作者動態添加任意部件配置，
 *      每個部件的選項稀有度範圍為 1~100，供應量由創作者設定；
 *      鑄造開始後凍結配置，不允許再作修改，並預留事件與接口供未來 NFT DEX 集成。
 */
contract CreatorNFT1155Unlimited is ERC1155, Ownable {
    // 定義部件配置結構
    struct PartConfig {
        string partName;           // 部件名稱
        uint256[] rarityForOption; // 每個選項的稀有度，範圍 1~100
        uint256[] supplyLimit;     // 每個選項的最大供應量
        uint256[] mintedCount;     // 每個選項已鑄造數量
    }

    // 動態存儲所有部件配置
    PartConfig[] public parts;

    // 鑄造開始後，配置會被凍結，不允許修改
    bool public configurationFrozen;

    // tokenId 自增計數器
    uint256 public nextTokenId;

    // 存儲 NFT 元數據：記錄每個 NFT 的部件選項與綜合稀有度
    struct NFTMetadata {
        uint8[] selectedOptions; // 每個部件選擇的選項索引
        uint256 overallRarity;   // 綜合稀有度
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
     * @dev 添加一個新的部件配置，僅 owner 可調用，且必須在配置凍結前添加。
     * @param _partName 部件名稱
     * @param _rarityForOption 每個選項的稀有度數組，值需在 1~100 之間
     * @param _supplyLimit 每個選項的最大供應量數組
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
        // 初始化 mintedCount 陣列
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
     * @dev 內部函數，計算綜合稀有度，這裡採用簡單平均：
     *      例如：如果選擇的稀有度為 [80, 40, 30, 10]，則綜合稀有度 = (80+40+30+10)/4
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
     * @dev 鑄造 NFT，僅 owner 調用；第一次鑄造時凍結部件配置。
     *      用戶提交 selections 陣列，表示每個部件所選擇的選項索引。
     * @param to 接收 NFT 的地址
     * @param selections 每個部件的選項索引，長度必須與 parts 的數量一致
     * @return tokenId 鑄造出的 NFT tokenId
     */
    function mintNFT1155(address to, uint8[] calldata selections) external onlyOwner returns (uint256) {
        require(selections.length == parts.length, "Selections length mismatch");
        if (!configurationFrozen) {
            configurationFrozen = true;
            emit ConfigurationFrozen();
        }
        // 檢查每個部件選項的供應量是否足夠
        for (uint256 i = 0; i < parts.length; i++) {
            uint8 optionIndex = selections[i];
            require(optionIndex < parts[i].supplyLimit.length, "Invalid option index");
            require(parts[i].mintedCount[optionIndex] < parts[i].supplyLimit[optionIndex], "Selected option sold out");
        }
        uint256 overallRarity = _calculateOverallRarity(selections);
        // 更新每個部件的 mintedCount
        for (uint256 i = 0; i < parts.length; i++) {
            parts[i].mintedCount[selections[i]]++;
        }
        uint256 tokenId = nextTokenId;
        nextTokenId++;
        nftMetadata[tokenId] = NFTMetadata({
            selectedOptions: selections,
            overallRarity: overallRarity
        });
        // 鑄造 NFT，數量為 1
        _mint(to, tokenId, 1, "");
        emit NFTMinted(tokenId, to, selections, overallRarity);
        return tokenId;
    }
} 