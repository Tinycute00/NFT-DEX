// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interfaces/IFLPContract.sol";

// 修改合约名称从 DummyFLP 修改为 MockFLP
contract MockFLP is IFLPContract {
    uint256 private _totalSupply;

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function mint(address /*to*/, uint256 flpTokenId, uint256 /*nftTokenId*/, uint256 /*rarity*/, uint256 /*weight*/) external override {
        // 简单的模拟铸造方法，将 _totalSupply 更新为传入的 flpTokenId
        _totalSupply = flpTokenId;
    }

    function burn(address /*from*/, uint256 tokenId) external override {
        // 简单模拟销毁逻辑
        if (_totalSupply == tokenId) {
            _totalSupply = tokenId - 1;
        }
    }
} 