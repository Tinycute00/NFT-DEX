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
 * @dev Contract for creators or projects to create NFTs.
 */
contract CreatorNFT is Ownable, ReentrancyGuard, AccessControl {
    // Enum for NFT types
    enum NFTType { ERC721, ERC1155 }

    // Structure to store NFT information
    struct NFTInfo {
        NFTType nftType;
        uint256 rarity;
        uint256 weight;
        string imageUrl; // Image URL
    }

    // NFT attributes contract
    INFTAttributes public nftAttributes;
    IPoolSystem public poolSystem;
    IFLPContract public flpContract;

    // Mapping to store NFT information by tokenId
    mapping(uint256 => NFTInfo) public nftInfo;

    // -------------------------------
    // Whitelist system structures
    // -------------------------------
    struct WhitelistEntry {
        uint8 phase; // Whitelist phase, e.g., 1: Guarantee, 2: First-Come-First-Serve, 3: Public Sale, 4: Others, 5: Others
        uint256 maxMint; // Maximum number of NFTs that can be minted by this address
        uint256 minted;  // Number of NFTs already minted by this address
        uint256 mintStartTime; // Minting start time (timestamp)
        uint256 mintEndTime;   // Minting end time
    }

    // Mapping to store whitelist entries for each address
    mapping(address => WhitelistEntry) public whitelistEntries;

    // Events
    event NFTCreated(uint256 indexed tokenId, NFTType nftType, uint256 rarity, uint256 weight, string imageUrl);
    event FLPMinted(address indexed to, uint256 indexed flpTokenId);

    // Define roles
    bytes32 public constant SECURITY_ROLE = keccak256("SECURITY_ROLE");
    
    // Token ID counter, internal visibility
    uint256 internal _tokenIdCounter;
    
    constructor(address _nftAttributes, address _poolSystem, address _flpContract) {
        nftAttributes = INFTAttributes(_nftAttributes);
        poolSystem = IPoolSystem(_poolSystem);
        flpContract = IFLPContract(_flpContract);
        
        // Set up roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(SECURITY_ROLE, msg.sender);
        
        // Initialize tokenId counter
        _tokenIdCounter = 0;
    }

    // Security role setter function
    function setSecurityRole(address account, bool approved) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (approved) {
            grantRole(SECURITY_ROLE, account);
        } else {
            revokeRole(SECURITY_ROLE, account);
        }
    }

    // Get the next available tokenId
    function getNextTokenId() public view returns (uint256) {
        return _tokenIdCounter + 1;
    }

    /**
     * @dev Create an ERC-721 NFT.
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
     * @dev Create an ERC-1155 NFT.
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
     * @dev Mint FLP token.
     */
    function _mintFLP(address to, uint256 /*tokenId*/, uint256 /*rarity*/, uint256 weight) internal returns (uint256) {
        uint256 flpTokenId = flpContract.totalSupply() + 1;
        flpContract.mint(to, flpTokenId, 0, 0, 0);
        uint256 extraFee = (weight * 10) / 100;
        poolSystem.updatePools(extraFee, true);
        return flpTokenId;
    }

    /**
     * @dev Calculate weight based on rarity.
     */
    function calculateWeight(uint256 rarity) internal pure returns (uint256) {
        // Calculate weight as rarity multiplied by 100
        return rarity * 100;
    }

    /**
     * @dev Get NFT information.
     */
    function getNFTInfo(uint256 tokenId) external view returns (NFTInfo memory) {
        return nftInfo[tokenId];
    }

    function _mintNFT(address to, uint256 tokenId) internal {
        // Simulate ERC721 minting; in practice, call the appropriate NFT token contract's mint method.
    }

    function _mintNFT1155(address to, uint256 tokenId, uint256 amount) internal {
        // Simulate ERC1155 minting; in practice, call the appropriate NFT token contract's mint method.
    }

    // -------------------------------
    // Whitelist System Functions
    // -------------------------------

    event WhitelistEntrySet(address indexed user, uint8 phase, uint256 maxMint, uint256 mintStartTime, uint256 mintEndTime);

    /**
     * @dev Set whitelist entry for a single address.
     * @notice Only the contract owner can call this function.
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
        require(_mintStartTime >= block.timestamp, "Start time must be in the future");
        
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
     * @dev Batch set whitelist entries.
     * @notice Only the contract owner can call this function.
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
     * @dev Remove an address from the whitelist.
     * @notice Only the contract owner can call this function.
     */
    function removeFromWhitelist(address _addr) external onlyOwner {
        delete whitelistEntries[_addr];
        emit WhitelistEntrySet(_addr, 0, 0, 0, 0);
    }

    /**
     * @dev Batch remove whitelist entries.
     * @notice Only the contract owner can call this function.
     */
    function removeFromWhitelistBatch(address[] calldata _addrs) external onlyOwner {
        for (uint256 i = 0; i < _addrs.length; i++) {
            delete whitelistEntries[_addrs[i]];
            emit WhitelistEntrySet(_addrs[i], 0, 0, 0, 0);
        }
    }

    /**
     * @dev Check if an address is whitelisted.
     */
    function isWhitelisted(address _addr) external view returns (bool) {
        return whitelistEntries[_addr].maxMint > 0;
    }

    /**
     * @dev Get whitelist information for an address.
     */
    function getWhitelistInfo(address _addr) external view returns (WhitelistEntry memory) {
        return whitelistEntries[_addr];
    }

    // -------------------------------
    // Minting Entry Points for Different Sale Phases
    // -------------------------------

    // currentPhase: 1: Guarantee, 2: First-Come-First-Serve, 3: Public Sale, 4: Others, 5: Others
    uint8 public currentPhase;
    // Mapping for minting price for each phase (in wei)
    mapping(uint8 => uint256) public phasePrice;

    // Admin can set the current sale phase
    function setCurrentPhase(uint8 _phase) external onlyOwner {
        currentPhase = _phase;
    }

    // Admin can set the minting price for a specific phase
    function setPhasePrice(uint8 _phase, uint256 _price) external onlyOwner {
        phasePrice[_phase] = _price;
    }

    // Guarantee Phase (phase == 1)
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

    // First-Come-First-Serve Phase (phase == 2)
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

    // Public Sale Phase (phase == 3)
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

    // Other Phase (phase == 4)
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
