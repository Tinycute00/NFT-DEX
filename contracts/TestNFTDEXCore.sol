// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./NFTDEXCore.sol";

contract TestNFTDEXCore is NFTDEXCore {
    // 將內部函數 _mintFLP 暴露給外部測試
    function testMintFLP(address to, uint256 weight) external returns (uint256) {
        return _mintFLP(to, weight);
    }
} 