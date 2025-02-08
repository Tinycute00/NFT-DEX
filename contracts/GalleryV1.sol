// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title GalleryV1
 * @dev Main contract for the NFT trading system implementing a fixed base price mechanism.
 */
contract GalleryV1 is 
    ERC721,
    Ownable,
    ReentrancyGuard,
    Pausable
{
    address public platformWallet;

    // Structure for NFT attributes, as imported from NFTAttributes
    struct Attributes {
        uint256[] values;      // Array of attribute values
        string[] names;        // Array of attribute names
        uint256 count;         // Total number of attributes
    }
    
    uint256 public constant MAX_ATTRIBUTES = 20;     // Maximum number of attributes allowed
    uint256 public constant MAX_ATTRIBUTE_VALUE = 1000; // Maximum attribute value allowed
    
    // Structure for market information, as imported from NFTMarket
    struct MarketInfo {
        uint256 basePool;        // Base pool balance
        uint256 basePoolTotal;   // Total accumulated base pool
        uint256 premiumPool;     // Premium pool balance
        bool isActive;           // Market activation status
    }
    
    struct NFTInfo {
        uint256 basePrice;      // Base price of NFT
        uint256 rarity;         // Rarity of NFT
        bool priceConfirmed;    // Flag indicating whether price is confirmed
        bool inSystemMarket;    // Flag indicating whether NFT is in the system market
        uint256 sellPrice;      // Price for selling to the system market
        uint256 sellTimestamp;  // Timestamp when the NFT was sold to the system market
    }
    
    uint256 private constant SYSTEM_FEE = 25;        // System fee (2.5%)
    uint256 private constant BASE_POOL_RATE = 200;   // Base pool rate (20%)
    uint256 private constant PREMIUM_POOL_RATE = 200; // Premium pool rate (20%)
    uint256 private constant SCALE = 1000;           // Scaling factor
    
    // Project phases
    enum ProjectPhase { Creation, Confirmed }
    
    // Structure to store project information
    struct ProjectInfo {
        address creator;        // Project creator
        uint256 totalMinted;    // Total number of minted NFTs
        uint256 maxSupply;      // Maximum NFT supply
        uint256 totalValue;     // Total project value
        ProjectPhase phase;     // Current project phase
    }
    
    // Constants
    uint256 public constant MIN_MINT_REQUIREMENT = 10;  // Minimum minting requirement
    uint256 public constant MAX_BATCH_SIZE = 50;        // Maximum batch operation size
    uint256 public constant MAX_PRICE_INCREASE = 1000;  // Maximum price increase (10x)
    
    // State variables
    ProjectInfo public projectInfo;
    mapping(uint256 => NFTInfo) public nfts;
    mapping(uint256 => Attributes) private tokenAttributes;
    MarketInfo public marketInfo;
    mapping(string => mapping(uint256 => uint256)) private attributeDistribution;
    mapping(string => uint256) private attributeCount;
    uint256 public totalRarityPoints;
    
    // Events
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
    
    // Error declarations
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
     * @dev Initialize the project.
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
     * @dev Mint an NFT.
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
     * @dev Set NFT attributes.
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
        
        // Update the attribute distribution
        _updateAttributeDistribution(tokenAttributes[tokenId], attrNames, attrValues);
        
        // Update the NFT's attributes
        tokenAttributes[tokenId].names = attrNames;
        tokenAttributes[tokenId].values = attrValues;
        tokenAttributes[tokenId].count = attrNames.length;
        
        // Calculate the new rarity
        uint256 newRarity = calculateRarity(tokenAttributes[tokenId]);
        require(newRarity > 0, "Invalid rarity");
        
        // Update total rarity points
        if (nfts[tokenId].rarity > 0) {
            _updateTotalRarityPoints(nfts[tokenId].rarity, newRarity);
        } else {
            _updateTotalRarityPoints(0, newRarity);
        }
        nfts[tokenId].rarity = newRarity;
        
        emit AttributesSet(tokenId, newRarity);
    }
    
    /**
     * @dev Confirm the project and set NFT prices.
     */
    function confirmProject() external onlyOwner {
        require(marketInfo.isActive, "Project not initialized");
        require(projectInfo.phase == ProjectPhase.Creation, "Not in creation phase");
        require(projectInfo.totalMinted >= MIN_MINT_REQUIREMENT, "Minimum mint requirement not met");
        require(totalRarityPoints > 0, "No rarity points");
        
        // Set base price for each NFT based on rarity distribution
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
     * @dev Emergency withdrawal of ETH from the contract.
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdraw failed");
    }
    
    /**
     * @dev Get NFT information for a given tokenId.
     */
    function getNFTInfo(uint256 tokenId) public view returns (NFTInfo memory) {
        require(ownerOf(tokenId) != address(0), "Token does not exist");
        return nfts[tokenId];
    }
    
    /**
     * @dev Batch sell NFTs to the system market.
     */
    function batchSellToSystem(uint256[] calldata tokenIds) external nonReentrant whenNotPaused validBatchSize(tokenIds.length) {
        uint256 totalPrice = 0;
        
        // Check conditions for each NFT
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(ownerOf(tokenIds[i]) == msg.sender, "Not token owner");
            require(projectInfo.phase == ProjectPhase.Confirmed, "Project not confirmed");
            
            uint256 price = getSystemPrice(tokenIds[i]);
            totalPrice += price;
        }
        
        require(address(this).balance >= totalPrice, "Insufficient contract balance");
        
        // Execute the sell transactions
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 price = getSystemPrice(tokenIds[i]);
            _handleSystemFee(price);
            _transfer(msg.sender, address(this), tokenIds[i]);
            nfts[tokenIds[i]].inSystemMarket = true;
            nfts[tokenIds[i]].sellPrice = price;
            nfts[tokenIds[i]].sellTimestamp = block.timestamp;
            
            emit NFTSoldToSystem(tokenIds[i], msg.sender, price);
        }
        
        // Transfer ETH to the seller in one batch to save gas
        payable(msg.sender).transfer(totalPrice);
        
        emit BatchOperationExecuted(msg.sender, tokenIds.length);
    }
    
    /**
     * @dev Batch buy NFTs from the system market.
     */
    function batchBuyFromSystem(uint256[] calldata tokenIds) external payable nonReentrant whenNotPaused validBatchSize(tokenIds.length) {
        require(marketInfo.isActive, "Market not active");
        require(projectInfo.phase == ProjectPhase.Confirmed, "Project not confirmed");
        
        uint256 totalPrice = 0;
        
        // Calculate total price for all NFTs and check conditions
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(nfts[tokenIds[i]].inSystemMarket, "Not in system market");
            uint256 price = getSystemPrice(nfts[tokenIds[i]].basePrice, nfts[tokenIds[i]].rarity);
            totalPrice += price;
        }
        
        require(msg.value >= totalPrice, "Insufficient payment");
        
        // Execute the purchase transactions
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 price = getSystemPrice(nfts[tokenIds[i]].basePrice, nfts[tokenIds[i]].rarity);
            _handleSystemFee(price);
            _transfer(address(this), msg.sender, tokenIds[i]);
            nfts[tokenIds[i]].inSystemMarket = false;
            
            emit SystemMarketTrade(tokenIds[i], msg.sender, price, true);
        }
        
        // Refund any excess ETH to the buyer
        if (msg.value > totalPrice) {
            (bool success, ) = payable(msg.sender).call{value: msg.value - totalPrice}("");
            require(success, "Refund failed");
        }
        
        emit BatchOperationExecuted(msg.sender, tokenIds.length);
    }
    
    /**
     * @dev Batch set NFT attributes.
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
            
            // Update attribute distribution
            _updateAttributeDistribution(tokenAttributes[tokenIds[i]], attrNames[i], attrValues[i]);
            
            // Update NFT attributes
            tokenAttributes[tokenIds[i]].names = attrNames[i];
            tokenAttributes[tokenIds[i]].values = attrValues[i];
            tokenAttributes[tokenIds[i]].count = attrNames[i].length;
            
            // Calculate new rarity
            uint256 newRarity = calculateRarity(tokenAttributes[tokenIds[i]]);
            require(newRarity > 0, "Invalid rarity");
            
            // Update total rarity points
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
     * @dev Pause the contract.
     */
    function pause() external onlyOwner {
        _pause();
        emit ContractPaused(msg.sender);
    }
    
    /**
     * @dev Unpause the contract.
     */
    function unpause() external onlyOwner {
        _unpause();
        emit ContractUnpaused(msg.sender);
    }
    
    /**
     * @dev Returns the contract version.
     */
    function version() external pure returns (string memory) {
        return "1.0.0";
    }
    
    /**
     * @dev Check the contract state.
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
     * @dev Get project information.
     */
    function getProjectInfo() public view returns (ProjectInfo memory) {
        return projectInfo;
    }
    
    /**
     * @dev Calculates the rarity of an NFT.
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
     * @dev Update the attribute distribution.
     */
    function _updateAttributeDistribution(
        Attributes storage oldAttrs,
        string[] memory newNames,
        uint256[] memory newValues
    ) internal {
        // Clear the previous attribute distribution
        if (oldAttrs.count > 0) {
            for (uint256 i = 0; i < oldAttrs.count; i++) {
                attributeDistribution[oldAttrs.names[i]][oldAttrs.values[i]] -= 1;
                attributeCount[oldAttrs.names[i]] -= 1;
            }
        }
        
        // Update the new attribute distribution
        for (uint256 i = 0; i < newNames.length; i++) {
            require(newValues[i] <= MAX_ATTRIBUTE_VALUE, "Attribute value too high");
            require(bytes(newNames[i]).length > 0, "Empty attribute name");
            
            attributeDistribution[newNames[i]][newValues[i]] += 1;
            attributeCount[newNames[i]] += 1;
        }
    }
    
    /**
     * @dev Update the total rarity points.
     */
    function _updateTotalRarityPoints(uint256 oldRarity, uint256 newRarity) internal {
        if (oldRarity > 0) {
            totalRarityPoints -= oldRarity;
        }
        totalRarityPoints += newRarity;
    }
    
    /**
     * @dev Calculates the system market price for an NFT.
     */
    function getSystemPrice(uint256 tokenId) public view returns (uint256) {
        require(ownerOf(tokenId) != address(0), "Token does not exist");
        return getSystemPrice(nfts[tokenId].basePrice, nfts[tokenId].rarity);
    }
    
    /**
     * @dev Processes the system fee and updates the pool.
     */
    function _handleSystemFee(uint256 price) internal returns (uint256) {
        uint256 fee = (price * SYSTEM_FEE) / SCALE;
        _updatePools(fee, true);
        return fee;
    }
    
    /**
     * @dev Dummy pause function.
     */
    function _pause() internal {
        // Implementation for pausing the contract
    }
    
    /**
     * @dev Dummy unpause function.
     */
    function _unpause() internal {
        // Implementation for unpausing the contract
    }
    
    // Fallback functions to receive ETH
    receive() external payable {}
    fallback() external payable {}

    // Additional logic for fee distribution and 90-day linear decay is not implemented here.
}