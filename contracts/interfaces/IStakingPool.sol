// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title StakingPool Interface
 * @notice Interface for a Staking Pool contract that manages user stakes and rewards.
 */
interface IStakingPool is IAccessControl {

    /**
     * @notice Emitted when a new staking pool is created.
     * @param poolID The unique identifier for the staking pool.
     * @param stakeDurationInDays The duration in days that user stakes will be locked.
     * @param APRWei The Annual Percentage Rate (APR) in Wei for the staking pool.
     * @param sender The address that created the staking pool.
     * @param stakeTokenAddress The address of the ERC20 stake token for the staking pool.
     * @param stakeTokenDecimal The decimal places of the ERC20 stake token.
     * @param rewardTokenAddress The address of the ERC20 reward token for the staking pool.
     * @param rewardTokenDecimal The decimal places of the ERC20 reward token.
     */
    event StakingPoolCreated(
        bytes32 indexed poolID,
        uint256 stakeDurationInDays,
        uint256 APRWei,
        address indexed sender,
        address stakeTokenAddress,
        uint256 stakeTokenDecimal,
        address rewardTokenAddress,
        uint256 rewardTokenDecimal,
        uint256 maxPoolSize
    );

    /**
     * @notice Emitted when an existing staking pool is opened to accept user stakes.
     * @param poolID The unique identifier for the staking pool.
     * @param sender The address that opened the staking pool.
     */
    event StakingPoolOpen(bytes32 indexed poolID, address indexed sender);

    /**
     * @notice Emitted when an existing staking pool is closed, rejecting user stakes.
     * @param poolID The unique identifier for the staking pool.
     * @param sender The address that closed the staking pool.
     */
    event StakingPoolClosed(bytes32 indexed poolID, address indexed sender);

    /**
     * @notice Emitted when an existing staking pool is suspended, preventing user claims and unstakes.
     * @param poolID The unique identifier for the staking pool.
     * @param sender The address that suspended the staking pool.
     */
    event StakingPoolDisabled(bytes32 indexed poolID, address indexed sender);

    /**
     * @notice Emitted when a suspended staking pool is resumed, allowing user claims and unstakes.
     * @param poolID The unique identifier for the staking pool.
     * @param sender The address that resumed the staking pool.
     */
    event StakingPoolEnabled(bytes32 indexed poolID, address indexed sender);

    /**
     * @notice Creates a new staking pool.
     * @param poolID The unique identifier for the staking pool.
     * @param stakeDurationInDays The duration in days that user stakes will be locked.
     * @param APRWei The Annual Percentage Rate (APR) in Wei for the staking pool.
     * @param stakeTokenAddress The address of the ERC20 stake token for the staking pool.
     * @param stakeTokenDecimal The decimal places of the ERC20 stake token.
     * @param rewardTokenAddress The address of the ERC20 reward token for the staking pool.
     * @param rewardTokenDecimal The decimal places of the ERC20 reward token.
     */
    function createStakingPool(
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
     * @notice Closes an existing staking pool, rejecting user stakes.
     * @param poolId The unique identifier for the staking pool.
     */
    function closeStakingPool(bytes32 poolId) external;

    /**
     * @notice Opens an existing staking pool to accept user stakes.
     * @param poolId The unique identifier for the staking pool.
     */
    function openStakingPool(bytes32 poolId) external;

    /**
     * @notice Suspends an existing staking pool, preventing user claims and unstakes.
     * @param poolId The unique identifier for the staking pool.
     */
    function disableStakingPool(bytes32 poolId) external;

    /**
     * @notice Resumes a suspended staking pool, allowing user claims and unstakes.
     * @param poolId The unique identifier for the staking pool.
     */
    function enableStakingPool(bytes32 poolId) external;

    /**
     * @notice Retrieves information about an existing staking pool.
     * @param poolId The unique identifier for the staking pool.
     * @return stakeDurationInDays The duration in days that user stakes will be locked.
     * @return APRWei The Annual Percentage Rate (APR) in Wei for the staking pool.
     * @return stakeTokenAddress The address of the ERC20 stake token for the staking pool.
     * @return stakeTokenDecimal The decimal places of the ERC20 stake token.
     * @return rewardTokenAddress The address of the ERC20 reward token for the staking pool.
     * @return rewardTokenDecimal The decimal places of the ERC20 reward token.
     * @return isOpen True if the staking pool is open to accept user stakes.
     * @return canClaimAndUnstake True if users are allowed to claim rewards and unstake from the staking pool.
     */
    function retrieveStakingPoolInformation(bytes32 poolId) external view returns(
        uint256 stakeDurationInDays,
        uint256 APRWei,
        address stakeTokenAddress,
        uint256 stakeTokenDecimal,
        address rewardTokenAddress,
        uint256 rewardTokenDecimal,
        bool isOpen,
        bool canClaimAndUnstake
    );

    /**
     * @notice Gets the maximum pool size for a given staking pool
     * @param poolID The unique identifier of the staking pool
     * @return maxPoolSize The maximum pool size for the specified staking pool
     */
    function getStakingPoolMaxPoolSize(bytes32 poolID) external view returns (uint maxPoolSize);
}