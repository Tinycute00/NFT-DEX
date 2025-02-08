// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IFLPContract {
    // Returns the current total supply
    function totalSupply() external view returns (uint256);
    
    // Mints a new FLP token to the specified address
    function mint(address to, uint256 flpTokenId, uint256 nftTokenId, uint256 rarity, uint256 weight) external;

    // Added: Burns an FLP token
    function burn(address from, uint256 tokenId) external;
} 