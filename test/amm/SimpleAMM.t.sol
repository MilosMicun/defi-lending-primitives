// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/amm/SimpleAMM.sol";

contract SimpleAMMTest is Test {
    SimpleAMM amm;

    function setUp() public {
        amm = new SimpleAMM(100 ether, 200_000 ether);
    }

    function testInitialSpotPrice0In1() public view {
        uint256 spotPrice = amm.getSpotPrice0In1();

        assertEq(spotPrice, 2_000e18);
    }

    function testInitialSpotPrice1In0() public view {
        uint256 spotPrice = amm.getSpotPrice1In0();

        assertEq(spotPrice, 5e14);
    }

    function testSwap0For1MovesPrice() public {
        uint256 priceBefore = amm.getSpotPrice0In1();

        amm.swap0For1(10 ether);

        uint256 priceAfter = amm.getSpotPrice0In1();

        assertLt(priceAfter, priceBefore);
    }

    function testLargeTradeHasMoreSlippageThanSmallTrade() public {
        // SMALL TRADE
        uint256 smallAmountIn = 1 ether;

        uint256 smallOut = amm.swap0For1(smallAmountIn);

        uint256 smallPrice = (smallAmountIn * 1e18) / smallOut;

        // reset (new AMM)
        amm = new SimpleAMM(100 ether, 200_000 ether);

        // LARGE TRADE
        uint256 largeAmountIn = 50 ether;

        uint256 largeOut = amm.swap0For1(largeAmountIn);

        uint256 largePrice = (largeAmountIn * 1e18) / largeOut;

        assertGt(largePrice, smallPrice);
    }

    function testCumulativePriceAccruesOverTime() public {
        uint256 cumulativeBefore = amm.price0CumulativeLast();

        vm.warp(block.timestamp + 10);

        amm.swap0For1(1 ether);

        uint256 cumulativeAfter = amm.price0CumulativeLast();

        assertGt(cumulativeAfter, cumulativeBefore);
    }

    function _computeTwap(uint256 cumulativeStart, uint256 cumulativeEnd, uint256 timeElapsed)
        internal
        pure
        returns (uint256)
    {
        return (cumulativeEnd - cumulativeStart) / timeElapsed;
    }

    function testBriefManipulationAffectsSpotMoreThanTwap() public {
        uint256 cumulativeStart = amm.price0CumulativeLast();
        uint256 spotBefore = amm.getSpotPrice0In1();

        // normal price lasts a long time
        vm.warp(block.timestamp + 100);
        amm.swap0For1(1 ether);

        // manipulate spot upward
        amm.swap1For0(100_000 ether);
        uint256 manipulatedSpot = amm.getSpotPrice0In1();

        // manipulated price lasts only briefly
        vm.warp(block.timestamp + 5);
        amm.swap0For1(1 ether);

        uint256 cumulativeEnd = amm.price0CumulativeLast();
        uint256 twap = _computeTwap(cumulativeStart, cumulativeEnd, 105);

        assertGt(manipulatedSpot, spotBefore);
        assertGt(twap, spotBefore);
        assertLt(twap, manipulatedSpot);
    }
}
