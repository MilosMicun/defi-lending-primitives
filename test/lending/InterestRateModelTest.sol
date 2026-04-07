// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {InterestRateModel} from "../../src/lending/InterestRateModel.sol";

contract InterestRateModelTest is Test {
    InterestRateModel internal model;

    function setUp() public {
        model = new InterestRateModel(
            0.02e18, // baseRate = 2%
            0.08e18, // slope1 = 8%
            0.9e18, // slope2 = 90%
            0.8e18, // kink = 80%
            0.1e18 // reserveFactor = 10%
        );
    }

    function test_DepositReducesRates() public {
        uint256 cash = 5e18;
        uint256 borrows = 96e18;

        uint256 uBefore = model.utilization(cash, borrows);
        uint256 bRateBefore = model.borrowRate(uBefore);
        uint256 sRateBefore = model.supplyRate(uBefore);

        // simulate deposit
        cash = 50e18;

        uint256 uAfter = model.utilization(cash, borrows);
        uint256 bRateAfter = model.borrowRate(uAfter);
        uint256 sRateAfter = model.supplyRate(uAfter);

        assertLt(uAfter, uBefore);
        assertLt(bRateAfter, bRateBefore);
        assertLt(sRateAfter, sRateBefore);
    }

    function test_BorrowRate_AtKink_IsBasePlusSlope1() public view {
        uint256 u = 0.8e18;

        uint256 rate = model.borrowRate(u);

        assertEq(rate, 0.1e18);
    }

    function test_HighUtilizationRates_ExactValues() public view {
        uint256 cash = 5e18;
        uint256 borrows = 95e18;

        uint256 u = model.utilization(cash, borrows);
        uint256 bRate = model.borrowRate(u);
        uint256 sRate = model.supplyRate(u);

        assertEq(u, 0.95e18);
        assertEq(bRate, 0.775e18);
        assertEq(sRate, 0.662625e18);
    }

    function test_ZeroUtilization_ReturnsBaseBorrowRate_AndZeroSupplyRate() public view {
        uint256 u = model.utilization(100e18, 0);
        uint256 bRate = model.borrowRate(u);
        uint256 sRate = model.supplyRate(u);

        assertEq(u, 0);
        assertEq(bRate, 0.02e18);
        assertEq(sRate, 0);
    }

    function test_Constructor_RevertsIfKinkIsZero() public {
        vm.expectRevert(InterestRateModel.InvalidKink.selector);
        new InterestRateModel(0.02e18, 0.08e18, 0.9e18, 0, 0.1e18);
    }

    function test_Constructor_RevertsIfKinkIsWad() public {
        vm.expectRevert(InterestRateModel.InvalidKink.selector);
        new InterestRateModel(0.02e18, 0.08e18, 0.9e18, 1e18, 0.1e18);
    }

    function test_Constructor_RevertsIfReserveFactorIsWad() public {
        vm.expectRevert(InterestRateModel.InvalidReserveFactor.selector);
        new InterestRateModel(0.02e18, 0.08e18, 0.9e18, 0.8e18, 1e18);
    }

    function test_RatesFromState_MatchesIndividualFunctions() public view {
        uint256 cash = 40e18;
        uint256 borrows = 60e18;

        (uint256 u, uint256 bRate, uint256 sRate) = model.ratesFromState(cash, borrows);

        assertEq(u, model.utilization(cash, borrows));
        assertEq(bRate, model.borrowRate(u));
        assertEq(sRate, model.supplyRate(u));
    }
}
