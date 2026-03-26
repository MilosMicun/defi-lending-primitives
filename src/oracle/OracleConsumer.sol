// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ChainlinkPriceFeedReader} from "./ChainlinkPriceFeedReader.sol";
import {OracleGuard} from "./OracleGuard.sol";

contract OracleConsumer {

    ChainlinkPriceFeedReader public immutable reader;
    uint256 public immutable maxDelay;

    constructor(address readerAddress, uint256 maxDelay_) {
        reader = ChainlinkPriceFeedReader(readerAddress);
        maxDelay = maxDelay_;
    }

    function getSafePrice() external view returns (uint256) {
        (uint256 price, uint256 updatedAt) = reader.readNormalizedTo1e18();

        OracleGuard.validate(price, updatedAt, maxDelay);

        return price;
    }

}