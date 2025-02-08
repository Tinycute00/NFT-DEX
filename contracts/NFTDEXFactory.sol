// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./NFTDEXCore.sol";

contract NFTDEXFactory {
    // 存储所有部署的 NFTDEXCore 合约地址
    address[] public deployedContracts;

    event NFTDEXCoreDeployed(address indexed contractAddress);

    // 修改 createNFTDEXCore 函數，將新部署的 NFTDEXCore 合約的所有權轉移給調用者
    function createNFTDEXCore() external returns (address) {
        NFTDEXCore newCore = new NFTDEXCore();
        newCore.transferOwnership(msg.sender); // 將所有權轉移給調用者
        deployedContracts.push(address(newCore));
        emit NFTDEXCoreDeployed(address(newCore));
        return address(newCore);
    }

    // 获取所有部署的 NFTDEXCore 合约地址
    function getDeployedContracts() external view returns (address[] memory) {
        return deployedContracts;
    }
} 