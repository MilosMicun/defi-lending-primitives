// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "../interfaces/AggregatorV3Interface.sol";

contract ChainlinkPriceFeedReader {
    AggregatorV3Interface public immutable FEED;
    uint8 public immutable FEED_DECIMALS;

    error OracleInvalidPrice();
    error OracleIncompleteRound();

    constructor(address feedAddress) {
        FEED = AggregatorV3Interface(feedAddress);
        FEED_DECIMALS = FEED.decimals();
    }

    function _fetchRaw() internal view returns (uint256 rawPrice, uint256 updatedAt) {
        (uint80 roundId, int256 answer,, uint256 timestamp, uint80 answeredInRound) = FEED.latestRoundData();

        if (answer <= 0) revert OracleInvalidPrice();
        if (timestamp == 0) revert OracleIncompleteRound();
        if (answeredInRound < roundId) revert OracleIncompleteRound();

        // casting to uint256 is safe because answer > 0 was checked above
        // forge-lint: disable-next-line(unsafe-typecast)
        return (uint256(answer), timestamp);
    }

    function read() external view returns (uint256 price, uint256 updatedAt) {
        return _fetchRaw();
    }

    function readNormalizedTo1e18() external view returns (uint256 price1e18, uint256 updatedAt) {
        (uint256 raw, uint256 timestamp) = _fetchRaw();

        if (FEED_DECIMALS == 18) {
            return (raw, timestamp);
        } else if (FEED_DECIMALS < 18) {
            return (raw * (10 ** (18 - FEED_DECIMALS)), timestamp);
        } else {
            return (raw / (10 ** (FEED_DECIMALS - 18)), timestamp);
        }
    }
}
