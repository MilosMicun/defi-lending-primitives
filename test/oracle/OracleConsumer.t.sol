// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {OracleConsumer} from "../../src/oracle/chainlink/OracleConsumer.sol";
import {ChainlinkPriceFeedReader} from "../../src/oracle/chainlink/ChainlinkPriceFeedReader.sol";
import {MockOracle} from "./mocks/MockOracle.sol";
import {OracleGuard} from "../../src/oracle/chainlink/OracleGuard.sol";

contract OracleConsumerTest is Test {
    OracleConsumer internal consumer;
    ChainlinkPriceFeedReader internal reader;
    MockOracle internal mockOracle;

    uint256 internal constant MAX_DELAY = 1 hours;
    uint256 internal constant MAX_DEVIATION_BPS = 500; // 5%

    function setUp() external {
        mockOracle = new MockOracle(8, 2000e8, block.timestamp);
        reader = new ChainlinkPriceFeedReader(address(mockOracle));
        consumer = new OracleConsumer(address(reader), MAX_DELAY, MAX_DEVIATION_BPS);
    }

    function test_UpdatePrice_FirstReadSetsLastAcceptedPrice() external {
        consumer.updatePrice();
        uint256 price = consumer.getPrice();
        assertEq(price, 2000e18);
        assertEq(consumer.lastAcceptedPrice(), 2000e18);
    }

    function test_UpdatePrice_RevertsWhenPriceIsStale() external {
        vm.warp(MAX_DELAY + 2);
        mockOracle.setUpdatedAt(block.timestamp - MAX_DELAY - 1);

        vm.expectRevert(abi.encodeWithSelector(OracleGuard.OracleStalePrice.selector, 1, block.timestamp, MAX_DELAY));
        consumer.updatePrice();
    }

    function test_UpdatePrice_AllowsPriceWithinDeviationLimit() external {
        consumer.updatePrice();
        mockOracle.setAnswer(2050e8);

        consumer.updatePrice();
        uint256 price = consumer.getPrice();

        assertEq(price, 2050e18);
        assertEq(consumer.lastAcceptedPrice(), 2050e18);
    }

    function test_UpdatePrice_RevertsWhenDeviationIsTooHigh() external {
        consumer.updatePrice();
        mockOracle.setAnswer(2200e8);

        vm.expectRevert(
            abi.encodeWithSelector(
                OracleGuard.OracleDeviationTooHigh.selector, 2000e18, 2200e18, 1000, MAX_DEVIATION_BPS
            )
        );
        consumer.updatePrice();
    }

    function test_UpdatePrice_DoesNotUpdateLastAcceptedPriceOnDeviationRevert() external {
        consumer.updatePrice();
        assertEq(consumer.lastAcceptedPrice(), 2000e18);

        mockOracle.setAnswer(2200e8);

        vm.expectRevert();
        consumer.updatePrice();

        assertEq(consumer.lastAcceptedPrice(), 2000e18);
    }

    function test_UpdatePrice_RevertsWhenPriceIsNegative() external {
        mockOracle.setAnswer(-1);

        vm.expectRevert(ChainlinkPriceFeedReader.OracleInvalidPrice.selector);
        consumer.updatePrice();
    }

    function test_UpdatePrice_AllowsPriceAtExactDeviationBoundary() external {
        consumer.updatePrice();
        mockOracle.setAnswer(2100e8);

        consumer.updatePrice();
        uint256 price = consumer.getPrice();

        assertEq(price, 2100e18);
        assertEq(consumer.lastAcceptedPrice(), 2100e18);
    }

    function test_UpdatePrice_RevertsWhenDownwardDeviationIsTooHigh() external {
        consumer.updatePrice();
        mockOracle.setAnswer(1500e8);

        vm.expectRevert(
            abi.encodeWithSelector(
                OracleGuard.OracleDeviationTooHigh.selector, 2000e18, 1500e18, 2500, MAX_DEVIATION_BPS
            )
        );
        consumer.updatePrice();
    }

    function test_GetPrice_RevertsWhenPriceNotInitialized() external {
        vm.expectRevert(OracleConsumer.PriceNotInitialized.selector);
        consumer.getPrice();
    }

    function test_GetPrice_ReturnsCorrectValueAfterUpdate() external {
        consumer.updatePrice();
        uint256 price = consumer.getPrice();

        assertEq(price, 2000e18);
        assertEq(consumer.lastAcceptedPrice(), 2000e18);
    }

    function test_UpdatePrice_RevertsWhenRoundIsIncomplete() external {
        mockOracle.setRoundData(2, 1);

        vm.expectRevert(ChainlinkPriceFeedReader.OracleIncompleteRound.selector);
        consumer.updatePrice();
    }
}
