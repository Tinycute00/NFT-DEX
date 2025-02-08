// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interfaces/IPoolSystem.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UserMarket is Ownable {
    IPoolSystem public poolSystem;
    address public paymentToken;

    // Events
    event UserMarketTrade(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);
    event PaymentTokenUpdated(address indexed newToken);

    constructor(address poolSystemAddress, address _paymentToken) {
        poolSystem = IPoolSystem(poolSystemAddress);
        paymentToken = _paymentToken;
    }

    /**
     * @dev Updates the payment token.
     */
    function updatePaymentToken(address newToken) external {
        paymentToken = newToken;
        emit PaymentTokenUpdated(newToken);
    }

    /**
     * @dev Facilitates trading between users.
     */
    function trade(uint256 tokenId, address seller, address buyer, uint256 price) external {
        // Process system fee
        uint256 fee = (price * 30) / 1000; // System fee (3%)
        poolSystem.updatePools(fee, true);

        // Transfer ETH or token to the seller
        if (paymentToken == address(0)) {
            uint256 finalPrice = price - fee;
            (bool success, ) = payable(seller).call{value: finalPrice}("");
            require(success, "Transfer failed");
        } else {
            uint256 finalPrice = price - fee;
            IERC20(paymentToken).transferFrom(buyer, seller, finalPrice);
        }

        emit UserMarketTrade(tokenId, seller, buyer, price);
    }
}
