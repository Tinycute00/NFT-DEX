// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IPoolSystem.sol";
import "./interfaces/IFLPContract.sol";

contract NFTStaking is Ownable, ReentrancyGuard {
    IERC721 public nftContract;
    IFLPContract public flpContract;
    IPoolSystem public poolSystem;

    struct StakeInfo {
        address owner;
        uint256 tokenId;
        uint256 stakedAt;
    }

    struct NFTInfo {
        uint256 rarity;
        uint256 weight;
    }

    mapping(uint256 => StakeInfo) public stakes;
    mapping(address => uint256[]) public stakedTokens;
    mapping(uint256 => NFTInfo) public nftInfo;

    event NFTStaked(address indexed owner, uint256 indexed tokenId, uint256 stakedAt);
    event NFTUnstaked(address indexed owner, uint256 indexed tokenId, uint256 unstakedAt);
    event FLPMinted(address indexed owner, uint256 indexed tokenId);

    constructor(address _nftContract, address _flpContract, address _poolSystem) {
        nftContract = IERC721(_nftContract);
        flpContract = IFLPContract(_flpContract);
        poolSystem = IPoolSystem(_poolSystem);
    }

    /**
     * @dev Stake NFT
     */
    function stakeNFT(uint256 tokenId) external nonReentrant {
        require(nftContract.ownerOf(tokenId) == msg.sender, "Not the owner of the NFT");
        nftContract.transferFrom(msg.sender, address(this), tokenId);

        stakes[tokenId] = StakeInfo({
            owner: msg.sender,
            tokenId: tokenId,
            stakedAt: block.timestamp
        });

        stakedTokens[msg.sender].push(tokenId);

        // 鑄造FLP
        uint256 flpTokenId = _mintFLP(msg.sender, tokenId);

        emit NFTStaked(msg.sender, tokenId, block.timestamp);
        emit FLPMinted(msg.sender, flpTokenId);
    }

    /**
     * @dev Unstake NFT and burn FLP
     */
    function unstakeNFT(uint256 tokenId) external nonReentrant {
        require(stakes[tokenId].owner == msg.sender, "Not the owner of the staked NFT");

        nftContract.transferFrom(address(this), msg.sender, tokenId);

        delete stakes[tokenId];
        _removeStakedToken(msg.sender, tokenId);

        // 銷毀FLP
        _burnFLP(msg.sender, tokenId);

        emit NFTUnstaked(msg.sender, tokenId, block.timestamp);
    }

    /**
     * @dev Mint FLP
     */
    function _mintFLP(address to, uint256 tokenId) internal returns (uint256) {
        uint256 flpTokenId = flpContract.totalSupply() + 1;
        uint256 rarity = nftInfo[tokenId].rarity;
        uint256 weight = nftInfo[tokenId].weight;
        // 將 FLP 與質押的 NFT 相關聯，傳入完整的 NFT 訊息
        flpContract.mint(to, flpTokenId, tokenId, rarity, weight);

        // 計算額外費用並更新溢價池（此費用屬於系統，不參與 FLP 分紅）
        uint256 extraFee = (weight * 10) / 100;
        poolSystem.updatePools(extraFee, true);

        return flpTokenId;
    }

    /**
     * @dev Burn FLP
     */
    function _burnFLP(address from, uint256 tokenId) internal {
        uint256 flpTokenId = flpContract.totalSupply();
        flpContract.burn(from, flpTokenId);
    }

    /**
     * @dev Remove staked token from the list
     */
    function _removeStakedToken(address owner, uint256 tokenId) internal {
        uint256[] storage tokens = stakedTokens[owner];
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == tokenId) {
                tokens[i] = tokens[tokens.length - 1];
                tokens.pop();
                break;
            }
        }
    }

    /**
     * @dev Get staked tokens of an owner
     */
    function getStakedTokens(address owner) external view returns (uint256[] memory) {
        return stakedTokens[owner];
    }
}
