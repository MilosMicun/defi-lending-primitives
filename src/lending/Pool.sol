// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Pool {
    using SafeERC20 for IERC20;

    IERC20 public collateralToken;
    IERC20 public debtToken;

    uint256 public ltvBps;
    uint256 public liquidationThresholdBps;
    uint256 public liquidationBonusBps;

    mapping(address => uint256) public collateralBalanceOf;
    mapping(address => uint256) public debtBalanceOf;

    uint256 public totalCollateral;
    uint256 public totalDebt;

    error ZeroAmount();
    error ZeroAddress();
    error InvalidRiskParameters();
    error NoCollateral();
    error BorrowExceedsLimit();
    error NoDebt();
    error RepayExceedsDebt();
    error PositionNotLiquidatable();
    error InsufficientCollateral();
    error InsufficientLiquidity();
    error WithdrawExceedsCollateral();
    error WithdrawalBreaksHealthFactor();

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event Liquidated(address indexed liquidator, address indexed user, uint256 repaidAmount, uint256 collateralSeized);

    constructor(
        address collateralToken_,
        address debtToken_,
        uint256 ltvBps_,
        uint256 liquidationThresholdBps_,
        uint256 liquidationBonusBps_
    ) {
        if (collateralToken_ == address(0) || debtToken_ == address(0)) {
            revert ZeroAddress();
        }

        if (
            ltvBps_ == 0 || liquidationThresholdBps_ == 0 || ltvBps_ >= liquidationThresholdBps_
                || liquidationThresholdBps_ > 10_000 || liquidationBonusBps_ > 10_000
        ) {
            revert InvalidRiskParameters();
        }

        collateralToken = IERC20(collateralToken_);
        debtToken = IERC20(debtToken_);
        ltvBps = ltvBps_;
        liquidationThresholdBps = liquidationThresholdBps_;
        liquidationBonusBps = liquidationBonusBps_;
    }

    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        collateralToken.safeTransferFrom(msg.sender, address(this), amount);

        collateralBalanceOf[msg.sender] += amount;
        totalCollateral += amount;

        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        uint256 collateral = collateralBalanceOf[msg.sender];
        if (amount > collateral) revert WithdrawExceedsCollateral();

        uint256 newCollateral = collateral - amount;
        uint256 debt = debtBalanceOf[msg.sender];

        if (debt != 0) {
            uint256 newHealthFactor = _healthFactor(newCollateral, debt);
            if (newHealthFactor < 1e18) revert WithdrawalBreaksHealthFactor();
        }

        collateralBalanceOf[msg.sender] = newCollateral;
        totalCollateral -= amount;

        collateralToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    function getMaxBorrow(address user) public view returns (uint256) {
        return (collateralBalanceOf[user] * ltvBps) / 10_000;
    }

    function borrow(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (collateralBalanceOf[msg.sender] == 0) revert NoCollateral();
        if (debtToken.balanceOf(address(this)) < amount) revert InsufficientLiquidity();

        uint256 newDebt = debtBalanceOf[msg.sender] + amount;

        if (newDebt > getMaxBorrow(msg.sender)) revert BorrowExceedsLimit();

        debtBalanceOf[msg.sender] = newDebt;
        totalDebt += amount;

        debtToken.safeTransfer(msg.sender, amount);

        emit Borrowed(msg.sender, amount);
    }

    // NOTE:
    // 72A intentionally assumes collateral and debt use the same 1:1 value basis.
    // There is no oracle integration yet, so HF and liquidation use this simplified model.
    function getHealthFactor(address user) public view returns (uint256) {
        return _healthFactor(collateralBalanceOf[user], debtBalanceOf[user]);
    }

    function isLiquidatable(address user) public view returns (bool) {
        return getHealthFactor(user) < 1e18;
    }

    function repay(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        uint256 debt = debtBalanceOf[msg.sender];
        if (debt == 0) revert NoDebt();
        if (amount > debt) revert RepayExceedsDebt();

        debtToken.safeTransferFrom(msg.sender, address(this), amount);

        debtBalanceOf[msg.sender] = debt - amount;
        totalDebt -= amount;

        emit Repaid(msg.sender, amount);
    }

    function liquidate(address user, uint256 repayAmount) external {
        if (repayAmount == 0) revert ZeroAmount();

        uint256 debt = debtBalanceOf[user];
        if (debt == 0) revert NoDebt();
        if (!isLiquidatable(user)) revert PositionNotLiquidatable();
        if (repayAmount > debt) revert RepayExceedsDebt();

        uint256 collateralToSeize = (repayAmount * (10_000 + liquidationBonusBps)) / 10_000;

        if (collateralToSeize > collateralBalanceOf[user]) {
            revert InsufficientCollateral();
        }

        debtToken.safeTransferFrom(msg.sender, address(this), repayAmount);

        debtBalanceOf[user] = debt - repayAmount;
        totalDebt -= repayAmount;

        collateralBalanceOf[user] -= collateralToSeize;
        totalCollateral -= collateralToSeize;

        collateralToken.safeTransfer(msg.sender, collateralToSeize);

        emit Liquidated(msg.sender, user, repayAmount, collateralToSeize);
    }

    function _healthFactor(uint256 collateral, uint256 debt) internal view returns (uint256) {
        if (debt == 0) return type(uint256).max;

        uint256 adjustedCollateral = (collateral * liquidationThresholdBps) / 10_000;
        return (adjustedCollateral * 1e18) / debt;
    }
}
