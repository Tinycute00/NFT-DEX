// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/INFTAttributes.sol";
import "./interfaces/IPoolSystem.sol";
import "./interfaces/IFLPContract.sol";

/**
 * @title CreatorNFT
 * @dev 用於創作者或項目創建NFT的合約
 */
contract CreatorNFT is Ownable, ReentrancyGuard, AccessControl {
    // NFT類型
    enum NFTType { ERC721, ERC1155 }

    // NFT信息結構體
    struct NFTInfo {
        NFTType nftType;
        uint256 rarity;
        uint256 weight;
        string imageUrl; // 圖片URL
    }

    // NFT屬性合約
    INFTAttributes public nftAttributes;
    IPoolSystem public poolSystem;
    IFLPContract public flpContract;

    // NFT信息映射
    mapping(uint256 => NFTInfo) public nftInfo;

    // -------------------------------
    // 新增白名單結構
    // -------------------------------
    struct WhitelistEntry {
        uint8 phase; // 白名單階段，例如 1: 保證, 2: 先搶先贏, 3: 公售, 4: 其他, 5: 其他
        uint256 maxMint; // 該地址允許鑄造 NFT 的最大數量
        uint256 minted;  // 該地址已鑄造數量
        uint256 mintStartTime; // 鑄造開始時間（時間戳）
        uint256 mintEndTime;   // 鑄造結束時間
    }

    // 白名單映射，記錄各地址的白名單設定
    mapping(address => WhitelistEntry) public whitelistEntries;

    // 事件
    event NFTCreated(uint256 indexed tokenId, NFTType nftType, uint256 rarity, uint256 weight, string imageUrl);
    event FLPMinted(address indexed to, uint256 indexed flpTokenId);

    // 定義角色
    bytes32 public constant SECURITY_ROLE = keccak256("SECURITY_ROLE");
    
    // 添加 tokenId 計數器，使用 internal 訪問權限
    uint256 internal _tokenIdCounter;
    
    constructor(address _nftAttributes, address _poolSystem, address _flpContract) {
        nftAttributes = INFTAttributes(_nftAttributes);
        poolSystem = IPoolSystem(_poolSystem);
        flpContract = IFLPContract(_flpContract);
        
        // 設置角色
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(SECURITY_ROLE, msg.sender);
        
        // 初始化 tokenId 計數器
        _tokenIdCounter = 0;
    }

    // 安全管理員設置函數
    function setSecurityRole(address account, bool approved) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (approved) {
            grantRole(SECURITY_ROLE, account);
        } else {
            revokeRole(SECURITY_ROLE, account);
        }
    }

    // 獲取下一個可用的 tokenId
    function getNextTokenId() public view returns (uint256) {
        return _tokenIdCounter + 1;
    }

    /**
     * @dev 創建ERC-721 NFT
     */
    function createERC721(address to, uint256 rarity, string memory imageUrl) external onlyOwner returns (uint256) {
        _tokenIdCounter++;
        uint256 newTokenId = _tokenIdCounter;
        
        require(rarity > 0, "Invalid rarity");
        require(nftInfo[newTokenId].rarity == 0, "NFT already exists");

        uint256 weight = calculateWeight(rarity);
        nftInfo[newTokenId] = NFTInfo({
            nftType: NFTType.ERC721,
            rarity: rarity,
            weight: weight,
            imageUrl: imageUrl
        });

        _mintNFT(to, newTokenId);
        emit NFTCreated(newTokenId, NFTType.ERC721, rarity, weight, imageUrl);
        
        return newTokenId;
    }

    /**
     * @dev 創建ERC-1155 NFT
     */
    function createERC1155(address to, uint256 rarity, uint256 amount, string memory imageUrl) external onlyOwner returns (uint256) {
        _tokenIdCounter++;
        uint256 newTokenId = _tokenIdCounter;
        
        require(rarity > 0, "Invalid rarity");
        require(nftInfo[newTokenId].rarity == 0, "NFT already exists");

        uint256 weight = calculateWeight(rarity);
        nftInfo[newTokenId] = NFTInfo({
            nftType: NFTType.ERC1155,
            rarity: rarity,
            weight: weight,
            imageUrl: imageUrl
        });

        _mintNFT1155(to, newTokenId, amount);
        emit NFTCreated(newTokenId, NFTType.ERC1155, rarity, weight, imageUrl);
        
        return newTokenId;
    }

    /**
     * @dev 鑄造FLP
     */
    function _mintFLP(address to, uint256 /*tokenId*/, uint256 /*rarity*/, uint256 weight) internal returns (uint256) {
        uint256 flpTokenId = flpContract.totalSupply() + 1;
        flpContract.mint(to, flpTokenId, 0, 0, 0);
        uint256 extraFee = (weight * 10) / 100;
        poolSystem.updatePools(extraFee, false);
        return flpTokenId;
    }

    /**
     * @dev 計算權重
     */
    function calculateWeight(uint256 rarity) internal pure returns (uint256) {
        // 根據稀有度計算權重
        return rarity * 100;
    }

    /**
     * @dev 獲取NFT信息
     */
    function getNFTInfo(uint256 tokenId) external view returns (NFTInfo memory) {
        return nftInfo[tokenId];
    }

    function _mintNFT(address to, uint256 tokenId) internal {
        // 模擬鑄造 ERC721 NFT 動作，例如僅以事件形式記錄
        // 實際上，請使用適當的 NFT 代幣合約的 mint 方法
    }

    function _mintNFT1155(address to, uint256 tokenId, uint256 amount) internal {
        // 模擬鑄造 ERC1155 NFT 動作
        // 實際上，請使用適當的 NFT 代幣合約的 mint 方法
    }

    // -------------------------------
    // 白名單系統功能
    // -------------------------------

    event WhitelistEntrySet(address indexed user, uint8 phase, uint256 maxMint, uint256 mintStartTime, uint256 mintEndTime);

    /**
     * @dev 設置單個地址的白名單
     * @notice 只有合約擁有者可以調用此函數
     */
    function setWhitelistEntry(
        address _addr,
        uint256 _phase,
        uint256 _maxMint,
        uint256 _mintStartTime,
        uint256 _mintEndTime
    ) public onlyOwner {
        require(_addr != address(0), "Invalid address");
        require(_phase > 0 && _phase <= 4, "Invalid phase");
        require(_maxMint > 0, "Invalid max mint amount");
        require(_mintEndTime > _mintStartTime, "Invalid time range");
        require(_mintStartTime >= block.timestamp, "Start time must be in future");
        
        whitelistEntries[_addr] = WhitelistEntry({
            phase: uint8(_phase),
            maxMint: _maxMint,
            minted: 0,
            mintStartTime: _mintStartTime,
            mintEndTime: _mintEndTime
        });
        
        emit WhitelistEntrySet(_addr, uint8(_phase), _maxMint, _mintStartTime, _mintEndTime);
    }

    /**
     * @dev 批量設置白名單
     * @notice 只有合約擁有者可以調用此函數
     */
    function setWhitelistEntries(
        address[] calldata _addrs, 
        uint8[] calldata _phases, 
        uint256[] calldata _maxMints, 
        uint256[] calldata _mintStartTimes, 
        uint256[] calldata _mintEndTimes
    ) external onlyOwner {
        require(_addrs.length == _phases.length && _addrs.length == _maxMints.length 
                && _addrs.length == _mintStartTimes.length && _addrs.length == _mintEndTimes.length, "Arrays length mismatch");
        for (uint256 i = 0; i < _addrs.length; i++) {
            setWhitelistEntry(_addrs[i], _phases[i], _maxMints[i], _mintStartTimes[i], _mintEndTimes[i]);
        }
    }

    /**
     * @dev 移除白名單
     * @notice 只有合約擁有者可以調用此函數
     */
    function removeFromWhitelist(address _addr) external onlyOwner {
        delete whitelistEntries[_addr];
        emit WhitelistEntrySet(_addr, 0, 0, 0, 0);
    }

    /**
     * @dev 批量移除白名單
     * @notice 只有合約擁有者可以調用此函數
     */
    function removeFromWhitelistBatch(address[] calldata _addrs) external onlyOwner {
        for (uint256 i = 0; i < _addrs.length; i++) {
            delete whitelistEntries[_addrs[i]];
            emit WhitelistEntrySet(_addrs[i], 0, 0, 0, 0);
        }
    }

    /**
     * @dev 檢查地址是否在白名單中
     */
    function isWhitelisted(address _addr) external view returns (bool) {
        return whitelistEntries[_addr].maxMint > 0;
    }

    /**
     * @dev 獲取白名單信息
     */
    function getWhitelistInfo(address _addr) external view returns (WhitelistEntry memory) {
        return whitelistEntries[_addr];
    }

    // -------------------------------
    // 四種銷售階段鑄造入口
    // -------------------------------

    // currentPhase: 1: 保證, 2: 先搶先贏, 3: 公售, 4: 其他, 5: 其他
    uint8 public currentPhase;
    // 對應每個階段的鑄造價格（單位：wei）
    mapping(uint8 => uint256) public phasePrice;

    // 管理員設定當前銷售階段
    function setCurrentPhase(uint8 _phase) external onlyOwner {
        currentPhase = _phase;
    }

    // 管理員設定特定階段的鑄造價格
    function setPhasePrice(uint8 _phase, uint256 _price) external onlyOwner {
        phasePrice[_phase] = _price;
    }

    // 保證階段 (phase == 1)
    function mintGuarantee(uint256 rarity, string memory imageUrl) external virtual payable returns (uint256) {
        _tokenIdCounter++;
        uint256 newTokenId = _tokenIdCounter;
        
        WhitelistEntry storage entry = whitelistEntries[msg.sender];
        require(entry.maxMint > 0, "Address not whitelisted");
        require(entry.phase == 1, "Not authorized for Guarantee phase");
        require(block.timestamp >= entry.mintStartTime && block.timestamp <= entry.mintEndTime, "Not in minting period");
        require(entry.minted < entry.maxMint, "Mint limit reached");
        require(msg.value == phasePrice[1], "Incorrect ETH value for Guarantee phase");
        require(rarity > 0, "Invalid rarity");

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
    function mintFirstComeFirstServe(uint256 rarity, string memory imageUrl) external virtual payable returns (uint256) {
        _tokenIdCounter++;
        uint256 newTokenId = _tokenIdCounter;
        
        WhitelistEntry storage entry = whitelistEntries[msg.sender];
        require(entry.maxMint > 0, "Address not whitelisted");
        require(entry.phase == 2, "Not authorized for First-Come-First-Serve phase");
        require(block.timestamp >= entry.mintStartTime && block.timestamp <= entry.mintEndTime, "Not in minting period");
        require(entry.minted < entry.maxMint, "Mint limit reached");
        require(msg.value == phasePrice[2], "Incorrect ETH value for First-Come-First-Serve phase");
        require(rarity > 0, "Invalid rarity");

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
    function mintPublicSale(uint256 rarity, string memory imageUrl) external virtual payable returns (uint256) {
        _tokenIdCounter++;
        uint256 newTokenId = _tokenIdCounter;
        
        WhitelistEntry storage entry = whitelistEntries[msg.sender];
        require(entry.maxMint > 0, "Address not whitelisted");
        require(entry.phase == 3, "Not authorized for Public Sale phase");
        require(block.timestamp >= entry.mintStartTime && block.timestamp <= entry.mintEndTime, "Not in minting period");
        require(entry.minted < entry.maxMint, "Mint limit reached");
        require(msg.value == phasePrice[3], "Incorrect ETH value for Public Sale phase");
        require(rarity > 0, "Invalid rarity");

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
    function mintOther(uint256 rarity, string memory imageUrl) external virtual payable returns (uint256) {
        _tokenIdCounter++;
        uint256 newTokenId = _tokenIdCounter;
        
        WhitelistEntry storage entry = whitelistEntries[msg.sender];
        require(entry.maxMint > 0, "Address not whitelisted");
        require(entry.phase == 4, "Not authorized for Other phase");
        require(block.timestamp >= entry.mintStartTime && block.timestamp <= entry.mintEndTime, "Not in minting period");
        require(entry.minted < entry.maxMint, "Mint limit reached");
        require(msg.value == phasePrice[4], "Incorrect ETH value for Other phase");
        require(rarity > 0, "Invalid rarity");

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
}
