// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interfaces/IPoolSystem.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SystemMarket is Ownable {
    IPoolSystem public poolSystem;
    address public paymentToken;

    // Events
    event SystemMarketTrade(uint256 indexed tokenId, address indexed trader, uint256 price, bool isBuy);
    event PaymentTokenUpdated(address indexed newToken);

    constructor(address poolSystemAddress, address _paymentToken) {
        poolSystem = IPoolSystem(poolSystemAddress);
        paymentToken = _paymentToken;
    }

    // ...existing code...
}
