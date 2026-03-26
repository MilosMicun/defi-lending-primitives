// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library OracleGuard {
    error OracleStalePrice(uint256 updatedAt, uint256 currentTime, uint256 maxDelay);
    error OracleInvalidPrice();
    error OracleDeviationTooHigh(uint256 oldPrice, uint256 newPrice, uint256 deviationBps, uint256 maxDeviationBps);

    function validate(uint256 price, uint256 updatedAt, uint256 maxDelay) internal view {
        if (price == 0) revert OracleInvalidPrice();

        uint256 age = block.timestamp - updatedAt;

        if(age > maxDelay){
            revert OracleStalePrice(updatedAt, block.timestamp, maxDelay);
        }

    }

    function deviationBps(uint256 oldPrice, uint256 newPrice) internal pure returns (uint256) {
        if (oldPrice == 0 || newPrice == 0) revert OracleInvalidPrice();

        uint256 diff = oldPrice > newPrice ? oldPrice - newPrice : newPrice - oldPrice;
        return (diff * 10_000) / oldPrice;
    }

    function validateDevotion(
        uint256 oldPrice,
        uint256 newPrice,
        uint256 maxDevotionBps
    ) internal pure {
        uint256 dev = deviationBps(oldPrice, newPrice);

        if (dev > maxDeviationBps){
            revert OracleDeviationTooHigh(oldPrice, newPrice, dev, maxDeviationBps);
        }
    }
}