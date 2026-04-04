// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Pool} from "../../src/lending/Pool.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";

contract PoolTest is Test {
    MockERC20 internal collateralToken;
    MockERC20 internal debtToken;
    Pool internal pool;

    address internal user;
    address internal liquidator;

    uint256 internal constant LTV_BPS = 7000;
    uint256 internal constant LIQUIDATION_THRESHOLD_BPS = 8000;
    uint256 internal constant LIQUIDATION_BONUS_BPS = 1000;

    uint256 internal constant STARTING_COLLATERAL = 1_000e18;
    uint256 internal constant POOL_DEBT_LIQUIDITY = 1_000_000e18;

    function setUp() public {
        user = makeAddr("user");
        liquidator = makeAddr("liquidator");

        collateralToken = new MockERC20("Collateral Token", "COL");
        debtToken = new MockERC20("Debt Token", "DEBT");

        pool = new Pool(
            address(collateralToken), address(debtToken), LTV_BPS, LIQUIDATION_THRESHOLD_BPS, LIQUIDATION_BONUS_BPS
        );

        collateralToken.mint(user, STARTING_COLLATERAL);
        debtToken.mint(address(pool), POOL_DEBT_LIQUIDITY);
    }

    function test_constructor_reverts_on_zero_addresses() public {
        vm.expectRevert(Pool.ZeroAddress.selector);
        new Pool(address(0), address(debtToken), LTV_BPS, LIQUIDATION_THRESHOLD_BPS, LIQUIDATION_BONUS_BPS);

        vm.expectRevert(Pool.ZeroAddress.selector);
        new Pool(address(collateralToken), address(0), LTV_BPS, LIQUIDATION_THRESHOLD_BPS, LIQUIDATION_BONUS_BPS);
    }

    function test_constructor_reverts_on_invalid_risk_parameters() public {
        vm.expectRevert(Pool.InvalidRiskParameters.selector);
        new Pool(address(collateralToken), address(debtToken), 8000, 8000, LIQUIDATION_BONUS_BPS);

        vm.expectRevert(Pool.InvalidRiskParameters.selector);
        new Pool(address(collateralToken), address(debtToken), 9000, 8000, LIQUIDATION_BONUS_BPS);

        vm.expectRevert(Pool.InvalidRiskParameters.selector);
        new Pool(address(collateralToken), address(debtToken), LTV_BPS, 10_001, LIQUIDATION_BONUS_BPS);
    }

    function test_deposit_updates_user_and_total_collateral() public {
        uint256 amount = 100e18;

        vm.startPrank(user);
        collateralToken.approve(address(pool), amount);
        pool.deposit(amount);
        vm.stopPrank();

        assertEq(pool.collateralBalanceOf(user), amount);
        assertEq(pool.totalCollateral(), amount);
    }

    function test_deposit_reverts_on_zero_amount() public {
        vm.prank(user);
        vm.expectRevert(Pool.ZeroAmount.selector);
        pool.deposit(0);
    }

    function test_withdraw_reduces_user_and_total_collateral() public {
        uint256 depositAmount = 300e18;
        uint256 withdrawAmount = 100e18;

        vm.startPrank(user);
        collateralToken.approve(address(pool), depositAmount);
        pool.deposit(depositAmount);
        pool.withdraw(withdrawAmount);
        vm.stopPrank();

        assertEq(pool.collateralBalanceOf(user), depositAmount - withdrawAmount);
        assertEq(pool.totalCollateral(), depositAmount - withdrawAmount);
        assertEq(collateralToken.balanceOf(user), STARTING_COLLATERAL - depositAmount + withdrawAmount);
    }

    function test_withdraw_reverts_on_zero_amount() public {
        vm.prank(user);
        vm.expectRevert(Pool.ZeroAmount.selector);
        pool.withdraw(0);
    }

    function test_withdraw_reverts_if_amount_exceeds_collateral() public {
        uint256 depositAmount = 100e18;

        vm.startPrank(user);
        collateralToken.approve(address(pool), depositAmount);
        pool.deposit(depositAmount);

        vm.expectRevert(Pool.WithdrawExceedsCollateral.selector);
        pool.withdraw(depositAmount + 1);
        vm.stopPrank();
    }

    function test_withdraw_reverts_if_it_breaks_health_factor() public {
        uint256 depositAmount = 1000e18;
        uint256 borrowAmount = 700e18;

        vm.startPrank(user);
        collateralToken.approve(address(pool), depositAmount);
        pool.deposit(depositAmount);
        pool.borrow(borrowAmount);

        vm.expectRevert(Pool.WithdrawalBreaksHealthFactor.selector);
        pool.withdraw(200e18);
        vm.stopPrank();
    }

    function test_getMaxBorrow_returns_correct_value() public {
        uint256 depositAmount = 1000e18;

        vm.startPrank(user);
        collateralToken.approve(address(pool), depositAmount);
        pool.deposit(depositAmount);
        vm.stopPrank();

        uint256 maxBorrow = pool.getMaxBorrow(user);

        assertEq(maxBorrow, (depositAmount * LTV_BPS) / 10_000);
    }

    function test_borrow_updates_debt_and_transfers_debt_token() public {
        uint256 depositAmount = 1000e18;
        uint256 borrowAmount = 500e18;

        vm.startPrank(user);
        collateralToken.approve(address(pool), depositAmount);
        pool.deposit(depositAmount);
        pool.borrow(borrowAmount);
        vm.stopPrank();

        assertEq(pool.debtBalanceOf(user), borrowAmount);
        assertEq(pool.totalDebt(), borrowAmount);
        assertEq(debtToken.balanceOf(user), borrowAmount);
    }

    function test_borrow_reverts_on_zero_amount() public {
        vm.prank(user);
        vm.expectRevert(Pool.ZeroAmount.selector);
        pool.borrow(0);
    }

    function test_borrow_reverts_without_collateral() public {
        vm.prank(user);
        vm.expectRevert(Pool.NoCollateral.selector);
        pool.borrow(100e18);
    }

    function test_borrow_reverts_if_exceeds_ltv() public {
        uint256 depositAmount = 1000e18;

        vm.startPrank(user);
        collateralToken.approve(address(pool), depositAmount);
        pool.deposit(depositAmount);

        uint256 maxBorrow = pool.getMaxBorrow(user);

        vm.expectRevert(Pool.BorrowExceedsLimit.selector);
        pool.borrow(maxBorrow + 1);
        vm.stopPrank();
    }

    function test_borrow_reverts_if_pool_has_insufficient_liquidity() public {
        MockERC20 lowLiquidityDebtToken = new MockERC20("Low Liquidity Debt", "LLD");
        Pool lowLiquidityPool = new Pool(
            address(collateralToken),
            address(lowLiquidityDebtToken),
            LTV_BPS,
            LIQUIDATION_THRESHOLD_BPS,
            LIQUIDATION_BONUS_BPS
        );

        uint256 depositAmount = 1000e18;

        vm.startPrank(user);
        collateralToken.approve(address(lowLiquidityPool), depositAmount);
        lowLiquidityPool.deposit(depositAmount);

        vm.expectRevert(Pool.InsufficientLiquidity.selector);
        lowLiquidityPool.borrow(100e18);
        vm.stopPrank();
    }

    function test_getHealthFactor_returns_correct_value() public {
        uint256 depositAmount = 1000e18;
        uint256 borrowAmount = 700e18;

        vm.startPrank(user);
        collateralToken.approve(address(pool), depositAmount);
        pool.deposit(depositAmount);
        pool.borrow(borrowAmount);
        vm.stopPrank();

        uint256 healthFactor = pool.getHealthFactor(user);
        uint256 expected = (((depositAmount * LIQUIDATION_THRESHOLD_BPS) / 10_000) * 1e18) / borrowAmount;

        assertEq(healthFactor, expected);
    }

    function test_getHealthFactor_returns_max_when_user_has_no_debt() public {
        uint256 depositAmount = 1000e18;

        vm.startPrank(user);
        collateralToken.approve(address(pool), depositAmount);
        pool.deposit(depositAmount);
        vm.stopPrank();

        uint256 healthFactor = pool.getHealthFactor(user);

        assertEq(healthFactor, type(uint256).max);
    }

    function test_isLiquidatable_returns_false_for_healthy_position() public {
        uint256 depositAmount = 1000e18;
        uint256 borrowAmount = 700e18;

        vm.startPrank(user);
        collateralToken.approve(address(pool), depositAmount);
        pool.deposit(depositAmount);
        pool.borrow(borrowAmount);
        vm.stopPrank();

        bool liquidatable = pool.isLiquidatable(user);

        assertFalse(liquidatable);
    }

    function test_isLiquidatable_returns_true_for_forced_unhealthy_position() public {
        uint256 depositAmount = 1000e18;
        uint256 borrowAmount = 700e18;

        vm.startPrank(user);
        collateralToken.approve(address(pool), depositAmount);
        pool.deposit(depositAmount);
        pool.borrow(borrowAmount);
        vm.stopPrank();

        vm.store(
            address(pool),
            keccak256(abi.encode(user, uint256(5))), // collateralBalanceOf slot
            bytes32(uint256(800e18))
        );

        assertTrue(pool.isLiquidatable(user));
    }

    function test_repay_reduces_user_and_total_debt() public {
        uint256 depositAmount = 1000e18;
        uint256 borrowAmount = 500e18;
        uint256 repayAmount = 200e18;

        vm.startPrank(user);
        collateralToken.approve(address(pool), depositAmount);
        pool.deposit(depositAmount);
        pool.borrow(borrowAmount);
        vm.stopPrank();

        debtToken.mint(user, repayAmount);

        vm.startPrank(user);
        debtToken.approve(address(pool), repayAmount);
        pool.repay(repayAmount);
        vm.stopPrank();

        assertEq(pool.debtBalanceOf(user), borrowAmount - repayAmount);
        assertEq(pool.totalDebt(), borrowAmount - repayAmount);
    }

    function test_repay_reverts_on_zero_amount() public {
        vm.prank(user);
        vm.expectRevert(Pool.ZeroAmount.selector);
        pool.repay(0);
    }

    function test_repay_reverts_when_user_has_no_debt() public {
        debtToken.mint(user, 100e18);

        vm.startPrank(user);
        debtToken.approve(address(pool), 100e18);
        vm.expectRevert(Pool.NoDebt.selector);
        pool.repay(100e18);
        vm.stopPrank();
    }

    function test_repay_reverts_when_amount_exceeds_debt() public {
        uint256 depositAmount = 1000e18;
        uint256 borrowAmount = 200e18;

        vm.startPrank(user);
        collateralToken.approve(address(pool), depositAmount);
        pool.deposit(depositAmount);
        pool.borrow(borrowAmount);
        vm.stopPrank();

        debtToken.mint(user, borrowAmount + 1);

        vm.startPrank(user);
        debtToken.approve(address(pool), borrowAmount + 1);
        vm.expectRevert(Pool.RepayExceedsDebt.selector);
        pool.repay(borrowAmount + 1);
        vm.stopPrank();
    }

    function test_liquidate_reduces_debt_and_transfers_collateral() public {
        uint256 depositAmount = 1000e18;
        uint256 borrowAmount = 700e18;
        uint256 repayAmount = 200e18;

        vm.startPrank(user);
        collateralToken.approve(address(pool), depositAmount);
        pool.deposit(depositAmount);
        pool.borrow(borrowAmount);
        vm.stopPrank();

        vm.store(
            address(pool),
            keccak256(abi.encode(user, uint256(5))), // collateralBalanceOf slot
            bytes32(uint256(800e18))
        );

        debtToken.mint(liquidator, repayAmount);

        vm.startPrank(liquidator);
        debtToken.approve(address(pool), repayAmount);

        uint256 collateralBefore = collateralToken.balanceOf(liquidator);

        pool.liquidate(user, repayAmount);
        vm.stopPrank();

        uint256 expectedSeize = (repayAmount * (10_000 + LIQUIDATION_BONUS_BPS)) / 10_000;

        assertEq(pool.debtBalanceOf(user), borrowAmount - repayAmount);
        assertEq(pool.totalDebt(), borrowAmount - repayAmount);
        assertEq(pool.totalCollateral(), depositAmount - expectedSeize);
        assertEq(collateralToken.balanceOf(liquidator), collateralBefore + expectedSeize);
    }

    function test_liquidate_reverts_when_position_is_healthy() public {
        uint256 depositAmount = 1000e18;
        uint256 borrowAmount = 500e18;

        vm.startPrank(user);
        collateralToken.approve(address(pool), depositAmount);
        pool.deposit(depositAmount);
        pool.borrow(borrowAmount);
        vm.stopPrank();

        assertFalse(pool.isLiquidatable(user));

        uint256 repayAmount = 100e18;

        debtToken.mint(liquidator, repayAmount);

        vm.startPrank(liquidator);
        debtToken.approve(address(pool), repayAmount);

        vm.expectRevert(Pool.PositionNotLiquidatable.selector);
        pool.liquidate(user, repayAmount);
        vm.stopPrank();
    }

    function test_liquidate_reverts_when_collateral_insufficient() public {
        uint256 depositAmount = 1000e18;
        uint256 borrowAmount = 700e18;
        uint256 repayAmount = 200e18;

        vm.startPrank(user);
        collateralToken.approve(address(pool), depositAmount);
        pool.deposit(depositAmount);
        pool.borrow(borrowAmount);
        vm.stopPrank();

        // Force the position into an unhealthy state by reducing collateral directly in storage
        // This simulates a price drop or external shock in a simplified model
        vm.store(
            address(pool),
            keccak256(abi.encode(user, uint256(5))), // collateralBalanceOf slot
            bytes32(uint256(100e18)) // drastically reduced collateral
        );

        // Confirm the position is now liquidatable
        assertTrue(pool.isLiquidatable(user));

        // Calculate expected seize:
        // seize = repayAmount * (1 + liquidationBonus)
        // = 200 * 1.10 = 220
        // Since user only has 100 collateral, liquidation should fail
        debtToken.mint(liquidator, repayAmount);

        vm.startPrank(liquidator);
        debtToken.approve(address(pool), repayAmount);

        // Expect revert because there is not enough collateral to cover seize amount
        vm.expectRevert(Pool.InsufficientCollateral.selector);
        pool.liquidate(user, repayAmount);
        vm.stopPrank();
    }
}
