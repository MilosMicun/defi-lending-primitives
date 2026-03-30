// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ChainlinkPriceFeedReader} from "./ChainlinkPriceFeedReader.sol";
import {OracleGuard} from "./OracleGuard.sol";

contract OracleConsumer {
    ChainlinkPriceFeedReader public immutable READER;
    uint256 public immutable MAX_DELAY;
    uint256 public immutable MAX_DEVIATION_BPS;
    uint256 public lastAcceptedPrice;

    error PriceNotInitialized();
    event PriceUpdated(uint256 price, uint256 timestamp);

    constructor(address readerAddress, uint256 maxDelay_, uint256 maxDeviationBps_) {
        READER = ChainlinkPriceFeedReader(readerAddress);
        MAX_DELAY = maxDelay_;
        MAX_DEVIATION_BPS = maxDeviationBps_;
    }

    function updatePrice() external {
        (uint256 price, uint256 updatedAt) = READER.readNormalizedTo1e18();

        OracleGuard.validate(price, updatedAt, MAX_DELAY);

        if (lastAcceptedPrice != 0) {
            OracleGuard.validateDeviation(lastAcceptedPrice, price, MAX_DEVIATION_BPS);
        }

        lastAcceptedPrice = price;

        emit PriceUpdated(price, block.timestamp);
    }

    function getPrice() external view returns (uint256) {
        if (lastAcceptedPrice == 0) revert PriceNotInitialized();
        return lastAcceptedPrice;
    }
}
