// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IFLPContract {
    // 返回當前的總供應量
    function totalSupply() external view returns (uint256);
    
    // 鑄造新的 FLP 代幣到指定地址
    function mint(address to, uint256 flpTokenId, uint256 nftTokenId, uint256 rarity, uint256 weight) external;

    // 新增銷毀 FLP 代幣方法
    function burn(address from, uint256 tokenId) external;
} 