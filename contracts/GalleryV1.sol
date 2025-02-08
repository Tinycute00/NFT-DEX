// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title GalleryV1
 * @dev NFT交易系統的主合約，實現固定基礎價格機制
 */
contract GalleryV1 is 
    ERC721,
    Ownable,
    ReentrancyGuard,
    Pausable
{
    address public platformWallet;

    // 從 NFTAttributes 導入的結構和常量
    struct Attributes {
        uint256[] values;      // 屬性值數組
        string[] names;        // 屬性名稱數組
        uint256 count;         // 屬性數量
    }
    
    uint256 public constant MAX_ATTRIBUTES = 20;     // 增加最大屬性數量
    uint256 public constant MAX_ATTRIBUTE_VALUE = 1000; // 增加最大屬性值
    
    // 從 NFTMarket 導入的結構和常量
    struct MarketInfo {
        uint256 basePool;        // 基礎池餘額
        uint256 basePoolTotal;   // 基礎池累計總額
        uint256 premiumPool;     // 溢價池餘額
        bool isActive;           // 市場是否活躍
    }
    
    struct NFTInfo {
        uint256 basePrice;      // 基礎價格
        uint256 rarity;         // 稀有度
        bool priceConfirmed;    // 價格是否確認
        bool inSystemMarket;    // 是否在系統市場中
        uint256 sellPrice;      // 賣入系統市場的價格
        uint256 sellTimestamp;  // 賣入系統市場的時間戳
    }
    
    uint256 private constant SYSTEM_FEE = 25;        // 系統費用 (2.5%)
    uint256 private constant BASE_POOL_RATE = 200;   // 基礎池比率 (20%)
    uint256 private constant PREMIUM_POOL_RATE = 200; // 溢價池比率 (20%)
    uint256 private constant SCALE = 1000;           // 比例基數
    
    // 項目階段
    enum ProjectPhase { Creation, Confirmed }
    
    // 項目信息
    struct ProjectInfo {
        address creator;        // 創建者地址
        uint256 totalMinted;    // 已鑄造總量
        uint256 maxSupply;      // 最大供應量
        uint256 totalValue;     // 總價值
        ProjectPhase phase;     // 項目階段
    }
    
    // 常量
    uint256 public constant MIN_MINT_REQUIREMENT = 10;  // 最小鑄造要求
    uint256 public constant MAX_BATCH_SIZE = 50;      // 最大批量操作數量
    uint256 public constant MAX_PRICE_INCREASE = 1000; // 最大價格增幅(10倍)
    
    // 狀態變量
    ProjectInfo public projectInfo;
    mapping(uint256 => NFTInfo) public nfts;
    mapping(uint256 => Attributes) private tokenAttributes;
    MarketInfo public marketInfo;
    mapping(string => mapping(uint256 => uint256)) private attributeDistribution;
    mapping(string => uint256) private attributeCount;
    uint256 public totalRarityPoints;
    
    // 事件
    event ProjectInitialized(address indexed creator, uint256 maxSupply, uint256 totalValue);
    event ProjectConfirmed();
    event NFTMinted(address indexed to, uint256 indexed tokenId);
    event AttributesSet(uint256 indexed tokenId, uint256 rarity);
    event ContractPaused(address indexed operator);
    event ContractUnpaused(address indexed operator);
    event BatchOperationExecuted(address indexed operator, uint256 count);
    event SystemMarketTrade(uint256 indexed tokenId, address indexed trader, uint256 price, bool isBuy);
    event NFTSoldToSystem(uint256 indexed tokenId, address indexed seller, uint256 price);
    event PriceConfirmed(uint256 indexed tokenId, uint256 basePrice);
    event PoolUpdated(uint256 basePool, uint256 premiumPool);
    
    // 錯誤定義
    error InvalidInitialization();
    error ProjectAlreadyInitialized();
    error InvalidMaxSupply();
    error InvalidTotalValue();
    error ProjectNotInitialized();
    error NotInCreationPhase();
    error MaxSupplyReached();
    error MinimumMintRequirementNotMet();
    error NoRarityPoints();
    error InvalidRarity();
    error InsufficientContractBalance();
    error NotTokenOwner();
    error NotInSystemMarket();
    error InsufficientPayment();
    error RefundFailed();
    error InvalidBatchSize();
    error ArrayLengthMismatch();
    error EmptyAttributeName();
    error AttributeValueTooHigh();
    error TokenDoesNotExist();
    
    modifier validBatchSize(uint256 size) {
        if (size == 0 || size > MAX_BATCH_SIZE) revert InvalidBatchSize();
        _;
    }
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() ERC721("Gallery", "GLR") {
        marketInfo.isActive = false;
        platformWallet = msg.sender;
    }
    
    /**
     * @dev 初始化項目
     */
    function initializeProject(uint256 maxSupply, uint256 totalValue) external onlyOwner {
        if (marketInfo.isActive) revert ProjectAlreadyInitialized();
        if (maxSupply == 0) revert InvalidMaxSupply();
        if (totalValue == 0) revert InvalidTotalValue();
        
        projectInfo = ProjectInfo({
            creator: msg.sender,
            totalMinted: 0,
            maxSupply: maxSupply,
            totalValue: totalValue,
            phase: ProjectPhase.Creation
        });
        
        marketInfo.isActive = true;
        emit ProjectInitialized(msg.sender, maxSupply, totalValue);
    }
    
    /**
     * @dev 鑄造NFT
     */
    function mint(address to) external onlyOwner whenNotPaused {
        if (!marketInfo.isActive) revert ProjectNotInitialized();
        if (projectInfo.phase != ProjectPhase.Creation) revert NotInCreationPhase();
        if (projectInfo.totalMinted >= projectInfo.maxSupply) revert MaxSupplyReached();
        
        uint256 tokenId = projectInfo.totalMinted + 1;
        _mint(to, tokenId);
        projectInfo.totalMinted += 1;
        
        emit NFTMinted(to, tokenId);
    }
    
    /**
     * @dev 設置NFT屬性
     */
    function setAttributes(
        uint256 tokenId,
        string[] memory attrNames,
        uint256[] memory attrValues
    ) external {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        require(attrNames.length > 0 && attrNames.length <= MAX_ATTRIBUTES, "Invalid attributes count");
        require(marketInfo.isActive, "Project not initialized");
        require(projectInfo.phase == ProjectPhase.Creation, "Not in creation phase");
        require(ownerOf(tokenId) != address(0), "Token does not exist");
        require(attrNames.length == attrValues.length, "Arrays length mismatch");
        
        // 更新屬性分佈
        _updateAttributeDistribution(tokenAttributes[tokenId], attrNames, attrValues);
        
        // 更新NFT屬性
        tokenAttributes[tokenId].names = attrNames;
        tokenAttributes[tokenId].values = attrValues;
        tokenAttributes[tokenId].count = attrNames.length;
        
        // 計算新的稀有度
        uint256 newRarity = calculateRarity(tokenAttributes[tokenId]);
        require(newRarity > 0, "Invalid rarity");
        
        // 更新NFT稀有度
        if (nfts[tokenId].rarity > 0) {
            _updateTotalRarityPoints(nfts[tokenId].rarity, newRarity);
        } else {
            _updateTotalRarityPoints(0, newRarity);
        }
        nfts[tokenId].rarity = newRarity;
        
        emit AttributesSet(tokenId, newRarity);
    }
    
    /**
     * @dev 確認項目並設置價格
     */
    function confirmProject() external onlyOwner {
        require(marketInfo.isActive, "Project not initialized");
        require(projectInfo.phase == ProjectPhase.Creation, "Not in creation phase");
        require(projectInfo.totalMinted >= MIN_MINT_REQUIREMENT, "Minimum mint requirement not met");
        require(totalRarityPoints > 0, "No rarity points");
        
        // 設置每個NFT的基礎價格
        for (uint256 i = 1; i <= projectInfo.totalMinted; i++) {
            require(nfts[i].rarity > 0, "NFT rarity not set");
            uint256 basePrice = (projectInfo.totalValue * nfts[i].rarity) / totalRarityPoints;
            require(basePrice > 0, "Invalid base price");
            
            nfts[i].basePrice = basePrice;
            nfts[i].priceConfirmed = true;
            
            emit PriceConfirmed(i, basePrice);
        }
        
        projectInfo.phase = ProjectPhase.Confirmed;
        emit ProjectConfirmed();
    }
    
    /**
     * @dev (Test Only) Activate market wrapper function. 
     * NOTE: This function is intended for testing/development only and should not be used in production.
     */
    // function activateMarket(uint256 maxSupply, uint256 totalValue) external onlyOwner {
    //     initializeProject(maxSupply, totalValue);
    // }
    
    /**
     * @dev 賣給系統市場
     */
    function sellToSystem(uint256 tokenId) external nonReentrant whenNotPaused {
        if (!marketInfo.isActive) revert ProjectNotInitialized();
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner();
        if (projectInfo.phase != ProjectPhase.Confirmed) revert("Project not confirmed");
        if (!nfts[tokenId].priceConfirmed) revert("Price not confirmed");
        
        uint256 price = getSystemPrice(nfts[tokenId].basePrice, nfts[tokenId].rarity);
        if (address(this).balance < price) revert InsufficientContractBalance();
        
        // 處理系統費用
        uint256 fee = _handleSystemFee(price);
        uint256 finalPrice = price - fee;
        
        // 轉移NFT到系統市場
        _transfer(msg.sender, address(this), tokenId);
        nfts[tokenId].inSystemMarket = true;
        nfts[tokenId].sellPrice = finalPrice;
        nfts[tokenId].sellTimestamp = block.timestamp;
        
        // 轉賬ETH給賣家
        (bool success, ) = payable(msg.sender).call{value: finalPrice}("");
        if (!success) revert("Transfer failed");
        
        emit NFTSoldToSystem(tokenId, msg.sender, price);
        emit SystemMarketTrade(tokenId, msg.sender, price, false);
    }
    
    /**
     * @dev 從系統市場購買
     */
    function buyFromSystem(uint256 tokenId) external payable nonReentrant {
        require(marketInfo.isActive, "Market not active");
        require(projectInfo.phase == ProjectPhase.Confirmed, "Project not confirmed");
        require(nfts[tokenId].inSystemMarket, "Not in system market");

        uint256 t = (block.timestamp - nfts[tokenId].sellTimestamp) / 1 days;
        require(t <= 90, "Price has fully decayed");

        uint256 premium = (nfts[tokenId].sellPrice - nfts[tokenId].basePrice) * (90 - t) / 90;
        uint256 currentPrice = nfts[tokenId].basePrice + premium;

        uint256 totalPrice = currentPrice; // 不再計算手續費

        require(msg.value >= totalPrice, "Insufficient payment");

        // 轉移NFT
        _transfer(address(this), msg.sender, tokenId);
        nfts[tokenId].inSystemMarket = false;

        // 退還多餘的ETH
        if (msg.value > totalPrice) {
            (bool success, ) = payable(msg.sender).call{value: msg.value - totalPrice}("");
            require(success, "Refund failed");
        }

        emit SystemMarketTrade(tokenId, msg.sender, totalPrice, true);
    }
    
    /**
     * @dev 獲取NFT屬性
     */
    function getAttributes(uint256 tokenId) external view returns (string[] memory, uint256[] memory, uint256) {
        require(ownerOf(tokenId) != address(0), "Token does not exist");
        return (
            tokenAttributes[tokenId].names,
            tokenAttributes[tokenId].values,
            tokenAttributes[tokenId].count
        );
    }
    
    /**
     * @dev 獲取NFT基礎價格
     */
    function getBasePrice(uint256 tokenId) public view returns (uint256) {
        require(ownerOf(tokenId) != address(0), "Token does not exist");
        return nfts[tokenId].basePrice;
    }
    
    /**
     * @dev 獲取NFT系統市場價格
     */
    function getSystemPrice(uint256 tokenId) public view returns (uint256) {
        require(ownerOf(tokenId) != address(0), "Token does not exist");
        return getSystemPrice(nfts[tokenId].basePrice, nfts[tokenId].rarity);
    }
    
    /**
     * @dev 緊急提款
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdraw failed");
    }
    
    /**
     * @dev 獲取NFT信息
     */
    function getNFTInfo(uint256 tokenId) public view returns (NFTInfo memory) {
        require(ownerOf(tokenId) != address(0), "Token does not exist");
        return nfts[tokenId];
    }
    
    /**
     * @dev 批量賣給系統市場
     */
    function batchSellToSystem(uint256[] calldata tokenIds) external nonReentrant whenNotPaused validBatchSize(tokenIds.length) {
        uint256 totalPrice = 0;
        
        // 先檢查所有條件
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(ownerOf(tokenIds[i]) == msg.sender, "Not token owner");
            require(projectInfo.phase == ProjectPhase.Confirmed, "Project not confirmed");
            
            uint256 price = getSystemPrice(tokenIds[i]);
            totalPrice += price;
        }
        
        require(address(this).balance >= totalPrice, "Insufficient contract balance");
        
        // 執行交易
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 price = getSystemPrice(tokenIds[i]);
            _handleSystemFee(price);
            _transfer(msg.sender, address(this), tokenIds[i]);
            nfts[tokenIds[i]].inSystemMarket = true;
            nfts[tokenIds[i]].sellPrice = price;
            nfts[tokenIds[i]].sellTimestamp = block.timestamp;
            
            emit NFTSoldToSystem(tokenIds[i], msg.sender, price);
        }
        
        // 一次性轉賬以節省gas
        payable(msg.sender).transfer(totalPrice);
        
        emit BatchOperationExecuted(msg.sender, tokenIds.length);
    }
    
    /**
     * @dev 批量從系統市場購買
     */
    function batchBuyFromSystem(uint256[] calldata tokenIds) external payable nonReentrant whenNotPaused validBatchSize(tokenIds.length) {
        require(marketInfo.isActive, "Market not active");
        require(projectInfo.phase == ProjectPhase.Confirmed, "Project not confirmed");
        
        uint256 totalPrice = 0;
        
        // 先計算總價並檢查條件
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(nfts[tokenIds[i]].inSystemMarket, "Not in system market");
            uint256 price = getSystemPrice(nfts[tokenIds[i]].basePrice, nfts[tokenIds[i]].rarity);
            totalPrice += price;
        }
        
        require(msg.value >= totalPrice, "Insufficient payment");
        
        // 執行購買
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 price = getSystemPrice(nfts[tokenIds[i]].basePrice, nfts[tokenIds[i]].rarity);
            _handleSystemFee(price);
            _transfer(address(this), msg.sender, tokenIds[i]);
            nfts[tokenIds[i]].inSystemMarket = false;
            
            emit SystemMarketTrade(tokenIds[i], msg.sender, price, true);
        }
        
        // 退還多餘的ETH
        if (msg.value > totalPrice) {
            (bool success, ) = payable(msg.sender).call{value: msg.value - totalPrice}("");
            require(success, "Refund failed");
        }
        
        emit BatchOperationExecuted(msg.sender, tokenIds.length);
    }
    
    /**
     * @dev 批量設置NFT屬性
     */
    function batchSetAttributes(
        uint256[] calldata tokenIds,
        string[][] memory attrNames,
        uint256[][] memory attrValues
    ) external whenNotPaused validBatchSize(tokenIds.length) {
        require(tokenIds.length == attrNames.length, "Arrays length mismatch");
        require(tokenIds.length == attrValues.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(ownerOf(tokenIds[i]) == msg.sender, "Not token owner");
            require(attrNames[i].length > 0 && attrNames[i].length <= MAX_ATTRIBUTES, "Invalid attributes count");
            require(marketInfo.isActive, "Project not initialized");
            require(projectInfo.phase == ProjectPhase.Creation, "Not in creation phase");
            require(ownerOf(tokenIds[i]) != address(0), "Token does not exist");
            require(attrNames[i].length == attrValues[i].length, "Arrays length mismatch");
            
            // 更新屬性分佈
            _updateAttributeDistribution(tokenAttributes[tokenIds[i]], attrNames[i], attrValues[i]);
            
            // 更新NFT屬性
            tokenAttributes[tokenIds[i]].names = attrNames[i];
            tokenAttributes[tokenIds[i]].values = attrValues[i];
            tokenAttributes[tokenIds[i]].count = attrNames[i].length;
            
            // 計算新的稀有度
            uint256 newRarity = calculateRarity(tokenAttributes[tokenIds[i]]);
            require(newRarity > 0, "Invalid rarity");
            
            // 更新NFT稀有度
            if (nfts[tokenIds[i]].rarity > 0) {
                _updateTotalRarityPoints(nfts[tokenIds[i]].rarity, newRarity);
            } else {
                _updateTotalRarityPoints(0, newRarity);
            }
            nfts[tokenIds[i]].rarity = newRarity;
            
            emit AttributesSet(tokenIds[i], newRarity);
        }
        
        emit BatchOperationExecuted(msg.sender, tokenIds.length);
    }
    
    /**
     * @dev 暫停合約
     */
    function pause() external onlyOwner {
        _pause();
        emit ContractPaused(msg.sender);
    }
    
    /**
     * @dev 恢復合約
     */
    function unpause() external onlyOwner {
        _unpause();
        emit ContractUnpaused(msg.sender);
    }
    
    /**
     * @dev 獲取合約版本
     */
    function version() external pure returns (string memory) {
        return "1.0.0";
    }
    
    /**
     * @dev 檢查合約狀態
     */
    function checkContractState() external view returns (
        bool isActive,
        bool isPaused,
        uint256 balance,
        uint256 totalMinted,
        uint256 maxSupply,
        ProjectPhase phase
    ) {
        return (
            marketInfo.isActive,
            paused(),
            address(this).balance,
            projectInfo.totalMinted,
            projectInfo.maxSupply,
            projectInfo.phase
        );
    }
    
    /**
     * @dev 獲取項目信息
     */
    function getProjectInfo() public view returns (ProjectInfo memory) {
        return projectInfo;
    }
    
    /**
     * @dev 計算NFT的稀有度
     */
    function calculateRarity(Attributes memory attributes) public pure returns (uint256) {
        if (attributes.count == 0) return 1;
        
        uint256 totalRarity = 0;
        uint256 maxPossibleRarity = 10000;
        
        for (uint256 i = 0; i < attributes.count; i++) {
            uint256 attrValue = attributes.values[i];
            require(attrValue <= MAX_ATTRIBUTE_VALUE, "Attribute value too high");
            
            uint256 scaledValue = (attrValue * maxPossibleRarity) / MAX_ATTRIBUTE_VALUE;
            uint256 attrRarity = scaledValue > 0 ? scaledValue : 1;
            
            require(attrRarity <= maxPossibleRarity, "Rarity exceeds maximum");
            require(totalRarity <= type(uint256).max - attrRarity, "Rarity sum would overflow");
            
            totalRarity += attrRarity;
        }
        
        uint256 avgRarity = (2 * totalRarity + attributes.count) / (2 * attributes.count);
        
        if (avgRarity > maxPossibleRarity) return maxPossibleRarity;
        return avgRarity > 0 ? avgRarity : 1;
    }
    
    /**
     * @dev 更新屬性分佈
     */
    function _updateAttributeDistribution(
        Attributes storage oldAttrs,
        string[] memory newNames,
        uint256[] memory newValues
    ) internal {
        // 清除舊的屬性分佈
        if (oldAttrs.count > 0) {
            for (uint256 i = 0; i < oldAttrs.count; i++) {
                attributeDistribution[oldAttrs.names[i]][oldAttrs.values[i]] -= 1;
                attributeCount[oldAttrs.names[i]] -= 1;
            }
        }
        
        // 更新新的屬性分佈
        for (uint256 i = 0; i < newNames.length; i++) {
            require(newValues[i] <= MAX_ATTRIBUTE_VALUE, "Attribute value too high");
            require(bytes(newNames[i]).length > 0, "Empty attribute name");
            
            attributeDistribution[newNames[i]][newValues[i]] += 1;
            attributeCount[newNames[i]] += 1;
        }
    }
    
    /**
     * @dev 更新總稀有度點數
     */
    function _updateTotalRarityPoints(uint256 oldRarity, uint256 newRarity) internal {
        if (oldRarity > 0) {
            totalRarityPoints -= oldRarity;
        }
        totalRarityPoints += newRarity;
    }
    
    /**
     * @dev 計算系統市場價格
     */
    function getSystemPrice(uint256 basePrice, uint256 rarity) public view returns (uint256) {
        if (marketInfo.premiumPool == 0) return basePrice;
        
        // 直接使用 premiumPool 作為可用溢價
        uint256 premium = (marketInfo.premiumPool * rarity) / 10000;
        return basePrice + premium;
    }
    
    /**
     * @dev 更新市場池
     */
    function _updatePools(uint256 amount, bool isSystemFee) internal {
        if (isSystemFee) {
            uint256 baseAmount = (amount * BASE_POOL_RATE) / SCALE;
            uint256 premiumAmount = (amount * PREMIUM_POOL_RATE) / SCALE;
            
            marketInfo.basePool += baseAmount;
            marketInfo.basePoolTotal += baseAmount;
            marketInfo.premiumPool += premiumAmount;
            
            emit PoolUpdated(marketInfo.basePool, marketInfo.premiumPool);
        } else {
            marketInfo.basePool += amount;
            marketInfo.basePoolTotal += amount;
            emit PoolUpdated(marketInfo.basePool, marketInfo.premiumPool);
        }
    }
    
    /**
     * @dev 處理系統費用
     */
    function _handleSystemFee(uint256 price) internal returns (uint256) {
        uint256 fee = (price * SYSTEM_FEE) / SCALE;
        _updatePools(fee, true);
        return fee;
    }
    
    // 接收ETH
    receive() external payable {}
    fallback() external payable {}

    // 添加手續費分配和 90 天線性衰減邏輯
    function handleSystemMarket(uint256 tokenId, uint256 sellPrice, uint256 basePrice) external {
        uint256 t = (block.timestamp - nfts[tokenId].sellTimestamp) / 1 days;
        require(t <= 90, "Price has fully decayed");

        uint256 premium = (sellPrice - basePrice) * (90 - t) / 90;
        uint256 currentPrice = basePrice + premium;

        // 計算手續費為交易金額的 10%
        uint256 fee = currentPrice / 10; // 10% 手續費
        uint256 premiumFee = (fee * 8) / 10; // 8% 進入溢價池
        uint256 platformFee = fee - premiumFee; // 2% 為平台收益

        // 更新溢價池
        marketInfo.premiumPool += premiumFee;

        // 將平台收益轉入平台錢包
        (bool success, ) = platformWallet.call{value: platformFee}("");
        require(success, "Transfer to platform wallet failed");
    }
}