// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interfaces/IPoolSystem.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UserMarket is Ownable {
    IPoolSystem public poolSystem;
    address public paymentToken;

    // 事件
    event UserMarketTrade(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);
    event PaymentTokenUpdated(address indexed newToken);

    constructor(address poolSystemAddress, address _paymentToken) {
        poolSystem = IPoolSystem(poolSystemAddress);
        paymentToken = _paymentToken;
    }

    /**
     * @dev 更新支付代幣
     */
    function updatePaymentToken(address newToken) external {
        paymentToken = newToken;
        emit PaymentTokenUpdated(newToken);
    }

    /**
     * @dev 用戶之間交易
     */
    function trade(uint256 tokenId, address seller, address buyer, uint256 price) external {
        // 處理系統費用
        uint256 fee = (price * 30) / 1000; // 系統費用 (3%)
        poolSystem.updatePools(fee, true);

        // 轉賬ETH或代幣給賣家
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
