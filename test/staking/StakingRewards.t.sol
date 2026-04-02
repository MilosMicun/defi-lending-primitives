// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StakingRewards} from "../../src/staking/StakingRewards.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";

contract StakingRewardsTest is Test {
    MockERC20 internal stakingToken;
    MockERC20 internal rewardToken;
    StakingRewards internal stakingRewards;

    address internal alice;
    address internal bob;

    uint256 internal constant STARTING_BALANCE = 1_000e18;
    uint256 internal constant REWARD_FUNDING = 1_000_000e18;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        stakingToken = new MockERC20("Stake Token", "STK");
        rewardToken = new MockERC20("Reward Token", "RWD");
        stakingRewards = new StakingRewards(address(stakingToken), address(rewardToken));
        stakingToken.mint(alice, STARTING_BALANCE);
        stakingToken.mint(bob, STARTING_BALANCE);
        rewardToken.mint(address(stakingRewards), REWARD_FUNDING);

        vm.prank(alice);
        stakingToken.approve(address(stakingRewards), type(uint256).max);

        vm.prank(bob);
        stakingToken.approve(address(stakingRewards), type(uint256).max);
    }

    function test_rewardPerToken_increases_over_time() public {
        vm.prank(stakingRewards.owner());
        stakingRewards.setRewardRate(1e18); // 1 token per second

        vm.prank(alice);
        stakingRewards.stake(100e18);

        uint256 initial = stakingRewards.rewardPerToken();

        vm.warp(block.timestamp + 100);

        uint256 updated = stakingRewards.rewardPerToken();

        assertGt(updated, initial);
        assertEq(updated, 1e18);
    }

    function test_new_staker_does_not_receive_past_rewards() public {
        vm.prank(stakingRewards.owner());
        stakingRewards.setRewardRate(1e18);

        vm.prank(alice);
        stakingRewards.stake(100e18);

        vm.warp(block.timestamp + 100);

        uint256 aliceEarnedBeforeBob = stakingRewards.earned(alice);
        uint256 bobEarnedBeforeStake = stakingRewards.earned(bob);

        vm.prank(bob);
        stakingRewards.stake(100e18);

        uint256 bobPaid = stakingRewards.userRewardPerTokenPaid(bob);
        uint256 bobEarnedAfterStake = stakingRewards.earned(bob);

        assertEq(aliceEarnedBeforeBob, 100e18);
        assertEq(bobEarnedBeforeStake, 0);

        assertEq(bobPaid, 1e18);
        assertEq(bobEarnedAfterStake, 0);
    }

    function test_earned_uses_checkpoint_accounting() public {
        vm.prank(stakingRewards.owner());
        stakingRewards.setRewardRate(1e18);

        vm.prank(alice);
        stakingRewards.stake(100e18);

        vm.warp(block.timestamp + 100);

        uint256 earnedBeforeCheckpoint = stakingRewards.earned(alice);
        uint256 storedRewardsBeforeCheckpoint = stakingRewards.rewards(alice);

        vm.prank(alice);
        stakingRewards.stake(100e18);

        uint256 storedRewardsAfterCheckpoint = stakingRewards.rewards(alice);
        uint256 paidAfterCheckpoint = stakingRewards.userRewardPerTokenPaid(alice);
        uint256 earnedAfterCheckpoint = stakingRewards.earned(alice);

        assertEq(earnedBeforeCheckpoint, 100e18);
        assertEq(storedRewardsBeforeCheckpoint, 0);

        assertEq(storedRewardsAfterCheckpoint, 100e18);
        assertEq(paidAfterCheckpoint, 1e18);
        assertEq(earnedAfterCheckpoint, 100e18);
    }

    function test_withdraw_checkpoints_rewards_before_balance_change() public {
        vm.prank(stakingRewards.owner());
        stakingRewards.setRewardRate(1e18);

        vm.prank(alice);
        stakingRewards.stake(100e18);

        vm.warp(block.timestamp + 100);

        uint256 earnedBeforeWithdraw = stakingRewards.earned(alice);

        vm.prank(alice);
        stakingRewards.withdraw(50e18);

        uint256 storedAfterWithdraw = stakingRewards.rewards(alice);
        uint256 earnedAfterWithdraw = stakingRewards.earned(alice);
        uint256 balanceAfterWithdraw = stakingRewards.balanceOf(alice);

        assertEq(earnedBeforeWithdraw, 100e18);

        assertEq(storedAfterWithdraw, 100e18);
        assertEq(earnedAfterWithdraw, 100e18);

        assertEq(balanceAfterWithdraw, 50e18);
    }

    function test_getReward_transfers_and_resets_rewards() public {
        vm.prank(stakingRewards.owner());
        stakingRewards.setRewardRate(1e18);

        vm.prank(alice);
        stakingRewards.stake(100e18);

        vm.warp(block.timestamp + 100);

        uint256 earnedBeforeClaim = stakingRewards.earned(alice);
        uint256 rewardTokenBalanceBefore = rewardToken.balanceOf(alice);

        vm.prank(alice);
        stakingRewards.getReward();

        uint256 rewardTokenBalanceAfter = rewardToken.balanceOf(alice);
        uint256 storedRewardsAfter = stakingRewards.rewards(alice);
        uint256 earnedAfter = stakingRewards.earned(alice);
        uint256 stakingBalanceAfter = stakingRewards.balanceOf(alice);

        assertEq(earnedBeforeClaim, 100e18);
        assertEq(rewardTokenBalanceBefore, 0);

        assertEq(rewardTokenBalanceAfter, 100e18);
        assertEq(storedRewardsAfter, 0);
        assertEq(earnedAfter, 0);

        assertEq(stakingBalanceAfter, 100e18);
    }

    function test_two_users_receive_proportional_rewards() public {
        vm.prank(stakingRewards.owner());
        stakingRewards.setRewardRate(1e18);

        vm.prank(alice);
        stakingRewards.stake(100e18);

        vm.warp(block.timestamp + 100);

        vm.prank(bob);
        stakingRewards.stake(100e18);

        vm.warp(block.timestamp + 100);

        uint256 aliceEarned = stakingRewards.earned(alice);
        uint256 bobEarned = stakingRewards.earned(bob);

        assertEq(aliceEarned, 150e18);
        assertEq(bobEarned, 50e18);
    }
}
