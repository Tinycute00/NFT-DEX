// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./NFTDEXInterface.sol";
import "./interfaces/IFLPContract.sol";
import "./interfaces/IPoolSystem.sol";
import "./MarketLib.sol";

/**
 * @title NFTDEXCore
 * @dev Core contract for the NFT DEX that provides market order functionalities as well as dual-pool and FLP mechanisms.
 *      The dual-pool mechanism ensures a minimum price for NFTs by considering their rarity and weight, while the FLP mechanism
 *      mints FLP tokens during trading and updates pool states.
 */
contract NFTDEXCore is NFTDEXInterface, Ownable {

    // --------------------------
    // Market Order Section
    // --------------------------

    struct Listing {
        address seller;
        uint256 price;
    }

    // Mapping from tokenId to Listing
    mapping(uint256 => Listing) public listings;

    // Events for market orders
    event NFTListed(uint256 indexed tokenId, uint256 price);
    event NFTCanceled(uint256 indexed tokenId);
    event NFTBought(uint256 indexed tokenId, address indexed buyer, uint256 price);

    // --------------------------
    // FLP Mechanism Section
    // --------------------------

    IFLPContract public flpContract;
    IPoolSystem public poolSystem;

    MarketLib.MarketInfo public marketInfo;

    // Platform fee address to receive platform revenue (1% fee)
    address public platformFeeAddress;

    function setPlatformFeeAddress(address _addr) external onlyOwner {
        require(_addr != address(0), "Platform fee address not set");
        platformFeeAddress = _addr;
    }

    function setFLPContract(address flpAddress) external onlyOwner {
        flpContract = IFLPContract(flpAddress);
    }

    function setPoolSystem(address poolSystemAddress) external onlyOwner {
        poolSystem = IPoolSystem(poolSystemAddress);
    }

    // Internal function: Mints an FLP token, calculates the extra fee (extra fee = (weight * 10) / 100), and updates the pool
    function _mintFLP(address to, uint256 weight) internal returns (uint256) {
        uint256 flpTokenId = flpContract.totalSupply() + 1;
        flpContract.mint(to, flpTokenId, 0, 0, 0);
        uint256 extraFee = (weight * 10) / 100;
        poolSystem.updatePools(extraFee, true);
        return flpTokenId;
    }

    // --------------------------
    // Market Order Functions
    // --------------------------

    function listNFT(uint256 tokenId, uint256 price) external override {
        listings[tokenId] = Listing({ seller: msg.sender, price: price });
        emit NFTListed(tokenId, price);
    }

    function cancelListing(uint256 tokenId) external override {
        Listing memory listing = listings[tokenId];
        require(listing.seller == msg.sender, "Not the seller");
        delete listings[tokenId];
        emit NFTCanceled(tokenId);
    }

    function buyNFT(uint256 tokenId) external payable override {
        Listing memory listing = listings[tokenId];
        require(listing.seller != address(0), "NFT not listed");
        require(msg.value >= listing.price, "Insufficient payment");
        require(platformFeeAddress != address(0), "Platform fee address not set");

        // Calculate a 3% fee
        uint256 fee = (listing.price * 3) / 100;
        uint256 sellerAmount = listing.price - fee;
        uint256 platformFee = (listing.price * 1) / 100; // 1% for the platform
        uint256 poolFee = (listing.price * 2) / 100;     // 2% to update the premium pool

        // Transfer the net amount to the seller
        payable(listing.seller).transfer(sellerAmount);
        // Transfer the platform fee
        payable(platformFeeAddress).transfer(platformFee);

        // Ensure poolSystem is a deployed contract
        require(address(poolSystem).code.length > 0, "PoolSystem is not a contract");

        // Update the pool: add 2% fee to the premium pool
        poolSystem.updatePools(poolFee, true);

        // Refund any excess ETH to the buyer
        uint256 refund = msg.value - listing.price;
        if (refund > 0) {
            payable(msg.sender).transfer(refund);
        }

        delete listings[tokenId];
        emit NFTBought(tokenId, msg.sender, listing.price);
    }

    function getListing(uint256 tokenId) external view override returns (address seller, uint256 price) {
        Listing memory listing = listings[tokenId];
        return (listing.seller, listing.price);
    }

    // Uses MarketLib to calculate the system market price
    function calculateSystemPrice(uint256 basePrice, uint256 rarity) external view returns (uint256) {
        return MarketLib.getSystemPrice(basePrice, rarity, marketInfo.premiumPool);
    }

    // Uses MarketLib to handle the system fee
    function handleSystemFee(uint256 currentPrice, address platformWallet) external returns (uint256) {
        return MarketLib.handleSystemFee(currentPrice, marketInfo, platformWallet);
    }
} 