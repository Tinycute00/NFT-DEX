// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interfaces/IFLPContract.sol";

// Changed contract name from DummyFLP to MockFLP
contract MockFLP is IFLPContract {
    uint256 private _totalSupply;

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function mint(address /*to*/, uint256 flpTokenId, uint256 /*nftTokenId*/, uint256 /*rarity*/, uint256 /*weight*/) external override {
        // Simple simulation of minting: update _totalSupply with the provided flpTokenId
        _totalSupply = flpTokenId;
    }

    function burn(address /*from*/, uint256 tokenId) external override {
        // Simple simulation of burning logic
        if (_totalSupply == tokenId) {
            _totalSupply = tokenId - 1;
        }
    }
} 