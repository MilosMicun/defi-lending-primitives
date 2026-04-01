// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract StakingRewards is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    uint256 public rewardRate;
    uint256 public rewardPerTokenStored;
    uint256 public lastUpdateTime;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    error ZeroAmount();
    error ZeroAddress();

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 oldRewardRate, uint256 newRewardRate);

    constructor(address stakingToken_, address rewardToken_) Ownable(msg.sender) {
        if (stakingToken_ == address(0) || rewardToken_ == address(0)) {
            revert ZeroAddress();
        }
        stakingToken = IERC20(stakingToken_);
        rewardToken = IERC20(rewardToken_);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }

        uint256 dt = block.timestamp - lastUpdateTime;
        uint256 reward = rewardRate * dt;

        return rewardPerTokenStored + (reward * 1e18) / totalSupply;
    }

    function earned(address account) public view returns (uint256) {
        uint256 userBalance = balanceOf[account];
        uint256 paid = userRewardPerTokenPaid[account];
        uint256 currentRewardPerToken = rewardPerToken();

        uint256 newlyEarned = (userBalance * (currentRewardPerToken - paid)) / 1e18;

        return rewards[account] + newlyEarned;
    }

    function _updateReward(address account) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;

        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
    }

    function stake(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        _updateReward(msg.sender);

        totalSupply += amount;
        balanceOf[msg.sender] += amount;

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        _updateReward(msg.sender);

        totalSupply -= amount;
        balanceOf[msg.sender] -= amount;

        stakingToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    function getReward() external {
        _updateReward(msg.sender);

        uint256 reward = rewards[msg.sender];
        if (reward == 0) return;

        rewards[msg.sender] = 0;

        rewardToken.safeTransfer(msg.sender, reward);

        emit RewardPaid(msg.sender, reward);
    }

    function setRewardRate(uint256 rewardRate_) external onlyOwner {
        uint256 oldRewardRate = rewardRate;

        _updateReward(address(0));
        rewardRate = rewardRate_;

        emit RewardRateUpdated(oldRewardRate, rewardRate_);
    }
}
