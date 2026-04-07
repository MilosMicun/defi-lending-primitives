// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract InterestRateModel {
    uint256 public constant WAD = 1e18;

    uint256 public immutable BASE_RATE;
    uint256 public immutable SLOPE1;
    uint256 public immutable SLOPE2;
    uint256 public immutable KINK;
    uint256 public immutable RESERVE_FACTOR;

    error InvalidKink();
    error InvalidReserveFactor();

    constructor(uint256 baseRate_, uint256 slope1_, uint256 slope2_, uint256 kink_, uint256 reserveFactor_) {
        if (kink_ == 0 || kink_ >= WAD) revert InvalidKink();
        if (reserveFactor_ >= WAD) revert InvalidReserveFactor();

        BASE_RATE = baseRate_;
        SLOPE1 = slope1_;
        SLOPE2 = slope2_;
        KINK = kink_;
        RESERVE_FACTOR = reserveFactor_;
    }

    function utilization(uint256 cash, uint256 borrows) public pure returns (uint256) {
        if (borrows == 0) return 0;

        uint256 total = cash + borrows;
        if (total == 0) return 0;

        return (borrows * WAD) / total;
    }

    function borrowRate(uint256 u) public view returns (uint256) {
        if (u <= KINK) {
            return BASE_RATE + (u * SLOPE1) / KINK;
        }

        uint256 excessUtilization = u - KINK;
        uint256 remainingRange = WAD - KINK;

        return BASE_RATE + SLOPE1 + (excessUtilization * SLOPE2) / remainingRange;
    }

    function supplyRate(uint256 u) external view returns (uint256) {
        uint256 bRate = borrowRate(u);
        uint256 rateToSuppliers = (bRate * u) / WAD;

        return (rateToSuppliers * (WAD - RESERVE_FACTOR)) / WAD;
    }

    function ratesFromState(uint256 cash, uint256 borrows)
        external
        view
        returns (uint256 u, uint256 bRate, uint256 sRate)
    {
        u = utilization(cash, borrows);
        bRate = borrowRate(u);

        uint256 rateToSuppliers = (bRate * u) / WAD;
        sRate = (rateToSuppliers * (WAD - RESERVE_FACTOR)) / WAD;
    }
}
