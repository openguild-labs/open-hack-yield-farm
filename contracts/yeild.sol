// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

/**
 * @title YieldFarm
 * @notice Challenge: Implement a yield farming contract with the following requirements:
 *
 * 1. Users can stake LP tokens and earn reward tokens
 * 2. Rewards are distributed based on time and amount staked
 * 3. Implement reward boosting mechanism for long-term stakers
 * 4. Add emergency withdrawal functionality
 * 5. Implement reward rate adjustment mechanism
 */

contract YieldFarm is ReentrancyGuard, Ownable {
    // LP token that users can stake
    IERC20 public lpToken;

    // Token given as reward
    IERC20 public rewardToken;

    // Reward rate per second
    uint256 public rewardRate;

    // Last update time
    uint256 public lastUpdateTime;

    // Reward per token stored
    uint256 public rewardPerTokenStored;

    // Total staked amount
    uint256 public totalStaked;

    // User struct to track staking info
    struct UserInfo {
        uint256 amount; // Amount of LP tokens staked
        uint256 startTime; // Time when user started staking
        uint256 rewardDebt; // Reward debt
        uint256 pendingRewards; // Unclaimed rewards
    }

    // Mapping of user address to their info
    mapping(address => UserInfo) public userInfo;

    // Boost multiplier thresholds (in seconds)
    uint256 public constant BOOST_THRESHOLD_1 = 7 days;
    uint256 public constant BOOST_THRESHOLD_2 = 30 days;
    uint256 public constant BOOST_THRESHOLD_3 = 90 days;

    // Events
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event EmergencyWithdrawn(address indexed user, uint256 amount);

    // TODO: Implement the following functions

    /**
     * @notice Initialize the contract with the LP token and reward token addresses
     * @param _lpToken Address of the LP token
     * @param _rewardToken Address of the reward token
     * @param _rewardRate Initial reward rate per second
     */
    constructor(
        address _lpToken,
        address _rewardToken,
        uint256 _rewardRate
    ) Ownable(msg.sender) {
        // TODO: Initialize contract state
        lpToken = IERC20(_lpToken);
        rewardToken = IERC20(_rewardToken);
        rewardRate = _rewardRate;
    }

    function updateReward(address _user) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;

        if (_user != address(0)) {
            UserInfo storage user = userInfo[_user];
            user.pendingRewards = earned(_user);
            user.rewardDebt = (user.amount * rewardPerTokenStored) / 1e18;
        }
    }

    function rewardPerToken() public view returns (uint256) {
        // TODO: Implement pending rewards calculation
        // Requirements:
        // 1. Calculate rewards since last update
        // 2. Apply boost multiplier
        // 3. Return total pending rewards
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        uint256 totalRewards = (block.timestamp - lastUpdateTime) * rewardRate;
        return rewardPerTokenStored + ((totalRewards * 1e18) / totalStaked);
    }

    function earned(address _user) public view returns (uint256) {
        // TODO: Implement pending rewards calculation
        // Requirements:
        // 1. Calculate rewards since last update
        // 2. Apply boost multiplier
        // 3. Return total pending rewards
        UserInfo storage user = userInfo[_user];
        if (user.amount == 0) {
            return 0;
        }
        uint256 currentRewardPerToken = rewardPerToken();
        uint256 boostMultiplier = calculateBoostMultiplier(_user);
        uint256 userRewards = ((user.amount * currentRewardPerToken) / 1e18) - user.rewardDebt;
        uint256 boostedRewards = (userRewards * boostMultiplier) / 100;
        return user.pendingRewards + boostedRewards;
}


    /**
     * @notice Stake LP tokens into the farm
     * @param _amount Amount of LP tokens to stake
     */
    function stake(uint256 _amount) external nonReentrant {
        // TODO: Implement staking logic
        // Requirements:
        require(_amount > 0, "Cannot stake 0");
        address sender = msg.sender;
        // 1. Update rewards
        updateReward(sender);
        // 2. Transfer LP tokens from user
        lpToken.transferFrom(sender, address(this), _amount);
        // 3. Update user info and total staked amount
        UserInfo storage user = userInfo[sender];
        user.amount += _amount;
        user.startTime = block.timestamp;
        totalStaked += _amount;
        // 4. Emit Staked event
        emit Staked(sender, _amount);
    }

    /**
     * @notice Withdraw staked LP tokens
     * @param _amount Amount of LP tokens to withdraw
     */
    function withdraw(uint256 _amount) external nonReentrant {
        // TODO: Implement withdrawal logic
        // Requirements:
        address sender = msg.sender;
        UserInfo storage user = userInfo[sender];
        require(user.amount >= _amount, "Insufficient balance");
        // 1. Update rewards
        updateReward(sender);
        // 2. Transfer LP tokens to user
        lpToken.transfer(sender, _amount);
        // 3. Update user info and total staked amount
        user.amount -= _amount;
        user.rewardDebt = (user.amount * rewardPerTokenStored) / 1e18;
        totalStaked -= _amount;
        // 4. Emit Withdrawn event
        emit Withdrawn(sender, _amount);
    }

    /**
     * @notice Claim pending rewards
     */
    function claimRewards() external nonReentrant {
        // TODO: Implement reward claiming logic
        // Requirements:
        // 1. Calculate pending rewards with boost multiplier
        // 2. Transfer rewards to user
        // 3. Update user reward debt
        // 4. Emit RewardsClaimed event
        address sender = msg.sender;
        updateReward(sender);
        UserInfo storage user = userInfo[sender];
        uint256 pendingRewards = earned(sender);
        require(pendingRewards > 0, "No rewards to claim");
        rewardToken.transfer(sender, pendingRewards);

        user.pendingRewards = 0;
        user.rewardDebt = (user.amount * rewardPerTokenStored) / 1e18;

        emit RewardsClaimed(sender, pendingRewards);
    }

    /**
     * @notice Emergency withdraw without caring about rewards
     */
    function emergencyWithdraw() external nonReentrant {
        // TODO: Implement emergency withdrawal
        // Requirements:
        // 1. Transfer all LP tokens back to user
        // 2. Reset user info
        // 3. Emit EmergencyWithdrawn event
        address sender = msg.sender;
        updateReward(sender);
        UserInfo storage user = userInfo[sender];
        uint256 amount = user.amount;
        if (amount > 0) {
            // Transfer LP tokens back to user
            lpToken.transfer(sender, amount);
            // Reset user info
            user.amount = 0;
            user.startTime = 0;
            user.rewardDebt = 0;
            user.pendingRewards = 0;
            totalStaked -= amount;
            emit EmergencyWithdrawn(sender, amount);
        }
    }

    /**
     * @notice Calculate boost multiplier based on staking duration
     * @param _user Address of the user
     * @return Boost multiplier (100 = 1x, 150 = 1.5x, etc.)
     */
    function calculateBoostMultiplier(
        address _user
    ) public view returns (uint256) {
        // TODO: Implement boost multiplier calculation
        // Requirements:
        // 1. Calculate staking duration
        // 2. Return appropriate multiplier based on duration thresholds
        uint256 startTime = userInfo[_user].startTime;
        uint256 stakingDuration = block.timestamp - startTime;
        if (stakingDuration >= BOOST_THRESHOLD_3) {
            return 200;
        } else if (stakingDuration >= BOOST_THRESHOLD_2) {
            return 150;
        } else if (stakingDuration >= BOOST_THRESHOLD_1) {
            return 125;
        }
        return 100;
    }

    /**
     * @notice Update reward rate
     * @param _newRate New reward rate per second
     */
    function updateRewardRate(uint256 _newRate) external onlyOwner {
        // TODO: Implement reward rate update logic
        // Requirements:
        // 1. Update rewards before changing rate
        // 2. Set new reward rate
        updateReward(address(0));
        rewardRate = _newRate;
    }

    /**
     * @notice View function to see pending rewards for a user
     * @param _user Address of the user
     * @return Pending reward amount
     */
    function pendingRewards(address _user) external view returns (uint256) {
        return earned(_user);
    }
}
