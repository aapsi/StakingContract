// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/access/IAccessControl.sol";

interface IFactoryStaking is IAccessControl {

    /**
    * @dev Emitted when a new staking pool is created from a staking pool contract.
    * @param poolID The ID of the newly created staking pool.
    * @param account The address of the account that created the staking pool.
    */
    event StakingPoolCreated(
        bytes32 indexed poolID,
        address indexed account
    );


    /**
    * @notice Emitted when stake has been placed by user
    * @param poolId The staking pool identifier
    * @param account The address of the user wallet that placed the stake
    * @param stakeToken The address of the ERC20 stake token
    * @param stakeAmountWei The amount of tokens staked in Wei
    * @param stakeTimestamp The timestamp as seconds since unix epoch when the stake was placed
    * @param stakeMaturityTimestamp The timestamp as seconds since unix epoch when the stake matures
    * @param rewardAtMaturityWei The expected reward in Wei at maturity
    */
    event Staked(
        bytes32 indexed poolId,
        address indexed account,
        address indexed stakeToken,
        uint256 stakeAmountWei,
        uint256 stakeTimestamp,
        uint256 stakeMaturityTimestamp,
        uint256 rewardAtMaturityWei
    );

    /**
     * @notice Emitted when reward has been claimed by user
     * @param poolId The staking pool identifier
     * @param account The address of the user wallet receiving funds
     * @param rewardToken The address of the transferred ERC20 token
     * @param rewardWei The amount of tokens transferred in Wei
     */
    event RewardClaimed(
        bytes32 indexed poolId,
        address indexed account,
        address indexed rewardToken,
        uint256 rewardWei
    );

    /**
     * @notice Emitted when stake with reward has been withdrawn by user
     * @param poolId The staking pool identifier
     * @param account The address of the user wallet that unstaked and received the funds
     * @param stakeToken The address of the ERC20 stake token
     * @param unstakeAmountWei The amount of stake tokens unstaked in Wei
     * @param rewardToken The address of the ERC20 reward token
     * @param rewardWei The amount of reward tokens claimed in Wei
     */
    event Unstaked(
        bytes32 indexed poolId,
        address indexed account,
        address indexed stakeToken,
        uint256 unstakeAmountWei,
        address rewardToken,
        uint256 rewardWei
    );

    /**
     * @notice Emitted when reward has been added to staking pool
     * @param poolId The staking pool identifier
     * @param sender The address that added the reward
     * @param rewardToken The address of the ERC20 reward token
     * @param rewardAmountWei The amount of reward tokens added in Wei
     */
    event StakingPoolRewardAdded(
        bytes32 indexed poolId,
        address indexed sender,
        address indexed rewardToken,
        uint256 rewardAmountWei
    );

    /**
     * @notice Creates a new staking pool from a staking pool contract.
     * @param poolID The unique identifier for the staking pool.
     * @param stakeDurationInDays The duration of the stake in days.
     * @param APRWei The Annual Percentage Rate (APR) for the staking pool in Wei.
     * @param stakeTokenAddress The address of the ERC20 token used for staking.
     * @param stakeTokenDecimal The decimal precision of the stake token.
     * @param rewardTokenAddress The address of the ERC20 token used for rewards.
     * @param rewardTokenDecimal The decimal precision of the reward token.
     */
    function createStakingPoolFromPoolContract(
        bytes32 poolID,
        uint256 stakeDurationInDays,
        uint256 APRWei,
        address stakeTokenAddress,
        uint256 stakeTokenDecimal,
        address rewardTokenAddress,
        uint256 rewardTokenDecimal,
        uint256 maxPoolSize
    ) external;

    /**
     * @notice Allows a user to stake tokens in a specific staking pool.
     * @param poolID The unique identifier for the staking pool.
     * @param stakeAmountInWei The amount of tokens to stake in Wei.
     */
    function stake(bytes32 poolID, uint256 stakeAmountInWei) external;


    /**
     * @notice Allows a user to claim the rewards from a staking pool.
     * @param poolID The unique identifier for the staking pool.
     */
    function claimPoolReward(bytes32 poolID) external;


    /**
     * @notice Allows a user to unstake tokens and claim rewards from a staking pool.
     * @param poolID The unique identifier for the staking pool.
     */
    function unstake(bytes32 poolID) external;


    /**
     * @notice Adds additional rewards to a staking pool.
     * @param poolID The unique identifier for the staking pool.
     * @param rewardAmountInWei The amount of additional rewards to add in Wei.
     */
    function addStakingPoolReward(bytes32 poolID, uint256 rewardAmountInWei) external;


    /**
     * @notice Retrieves the summary information of a staking pool.
     * @param poolID The unique identifier for the staking pool.
     * @return totalRewardWei The total rewards in Wei.
     * @return totalStakedWei The total staked amount in Wei.
     * @return rewardToBeDistributedWei The reward to be distributed in Wei.
     * @return poolSizeWei The size of the staking pool in Wei.
     * @return isOpen A flag indicating whether the staking pool is open.
     * @return canClaimAndUnstake A flag indicating whether users can claim and unstake from the pool.
     */
    function getStakingPoolSummary(bytes32 poolID)
        external
        view
        returns (
            uint256 totalRewardWei,
            uint256 totalStakedWei,
            uint256 rewardToBeDistributedWei,
            uint256 poolSizeWei,
            bool isOpen,
            bool canClaimAndUnstake
        );


    /**
     * @notice Retrieves information about a user's stake in a staking pool.
     * @param poolID The unique identifier for the staking pool.
     * @param account The address of the user.
     * @return stakeAmountInWei The amount of tokens staked by the user in Wei.
     * @return stakeTimestamp The timestamp when the stake was placed.
     * @return stakeMaturityTimestamp The timestamp when the stake matures.
     * @return rewardAtStakeMaturityWei The expected reward at stake maturity in Wei.
     * @return rewardClaimedWei The amount of rewards claimed by the user in Wei.
     * @return canClaimAndUnstake A flag indicating whether the user can claim and unstake.
     */
    function retrieveStakeInfo(bytes32 poolID, address account)
        external
        view
        returns (
            uint256 stakeAmountInWei,
            uint256 stakeTimestamp,
            uint256 stakeMaturityTimestamp,
            uint256 rewardAtStakeMaturityWei,
            uint256 rewardClaimedWei,
            bool canClaimAndUnstake
        );

}
