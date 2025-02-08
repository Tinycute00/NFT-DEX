// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./NFTDEXCore.sol";

contract NFTDEXFactory {
    // Stores all deployed NFTDEXCore contract addresses
    address[] public deployedContracts;

    event NFTDEXCoreDeployed(address indexed contractAddress);

    // Modified createNFTDEXCore function to transfer ownership of the deployed NFTDEXCore contract to the caller
    function createNFTDEXCore() external returns (address) {
        NFTDEXCore newCore = new NFTDEXCore();
        newCore.transferOwnership(msg.sender); // Transfer ownership to the caller
        deployedContracts.push(address(newCore));
        emit NFTDEXCoreDeployed(address(newCore));
        return address(newCore);
    }

    // Returns all deployed NFTDEXCore contract addresses
    function getDeployedContracts() external view returns (address[] memory) {
        return deployedContracts;
    }
} 