// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ChainlinkPriceFeedReader} from "./ChainlinkPriceFeedReader.sol";
import {OracleGuard} from "./OracleGuard.sol";

contract OracleConsumer {
    ChainlinkPriceFeedReader public immutable READER;
    uint256 public immutable MAX_DELAY;

    constructor(address readerAddress, uint256 maxDelay_) {
        READER = ChainlinkPriceFeedReader(readerAddress);
        MAX_DELAY = maxDelay_;
    }

    function getSafePrice() external view returns (uint256) {
        (uint256 price, uint256 updatedAt) = READER.readNormalizedTo1e18();

        OracleGuard.validate(price, updatedAt, MAX_DELAY);

        return price;
    }
}
