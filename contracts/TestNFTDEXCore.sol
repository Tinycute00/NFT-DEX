// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./NFTDEXCore.sol";

contract TestNFTDEXCore is NFTDEXCore {
    // Exposes the internal _mintFLP function for testing via the testMintFLP method.
    function testMintFLP(address to, uint256 weight) external returns (uint256) {
        return _mintFLP(to, weight);
    }
} 