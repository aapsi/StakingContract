// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./AdminOnly.sol";
import "./interfaces/IStakingPool.sol";
import "./interfaces/IFactoryStaking.sol";

contract FactoryStaking is AdminOnly, IFactoryStaking{

    using SafeERC20 for IERC20;

    // Constants
    uint256 public constant TOKEN_MAX_DECIMALS = 18;
    uint256 public constant DAYS_IN_YEAR = 365;
    uint256 public constant SECONDS_IN_DAY = 86400;
    uint256 public constant PERCENT_100_WEI = 100 ether;
    
    // Address of the staking pool contract
    address public stakingPoolContract;

    struct StakingPoolSummary {
        uint256 totalRewardWei; // total pool reward in Wei
        uint256 totalStakedWei; // total staked inside pool in Wei
        uint256 rewardToBeDistributedWei; // allocated pool reward to be distributed in Wei
        uint256 maxPoolSize;  
    }

  // Struct to store summary information about staking pools
    struct StakeConfig {
        uint256 stakeAmountInWei;
        uint256 stakeTimestamp;
        uint256 stakeMaturityTimestamp; // timestamp when the stake matures
        uint256 rewardAtMaturityWei; // estimated reward at maturity in Wei
        uint256 rewardClaimedWei; // reward claimed in Wei
        bool canClaimAndUnstake;
        bool stakeExists;
    }

    // Mapping to store stake configurations using a combination of pool ID and user account
    mapping(bytes => StakeConfig) private _AllStakes;

    // Mapping to store staking pool summaries using pool ID
    mapping(bytes32 => StakingPoolSummary) private _StakingPoolSummary;

    constructor(address stakingPoolContract_) {
        require(stakingPoolContract_ != address(0), "Staking Pool contract doesn't exist");

        stakingPoolContract = stakingPoolContract_;
    }

    /**
     * @inheritdoc IFactoryStaking
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
    ) external onlyRole(CONTRACT_ADMIN_ROLE) 
    {
        IStakingPool(stakingPoolContract).createStakingPool(
            poolID,
            stakeDurationInDays,
            APRWei,
            stakeTokenAddress,
            stakeTokenDecimal,
            rewardTokenAddress,
            rewardTokenDecimal,
            maxPoolSize
        );

        emit StakingPoolCreated(poolID, msg.sender);
    }

    /**
     * @inheritdoc IFactoryStaking
     */
    function stake(bytes32 poolID, uint256 stakeAmountInWei) external override {
        require(stakeAmountInWei > 0, "Stake Amount should be greater than 0");

        require(
            _StakingPoolSummary[poolID].totalStakedWei + stakeAmountInWei <= _getStakingPoolConfig(poolID),
            "Stake amount exceeds maximum allowed for the pool"
        );

        (
            uint256 stakeDurationInDays,
            uint256 APRWei,
            address stakeTokenAddress,
            uint256 stakeTokenDecimal,
            ,
            uint256 rewardTokenDecimal,
            bool isOpen,
            
        ) = _retrieveStakingPoolInformation(poolID);


        require(isOpen, "Staking pool is not open");

        uint256 timestampForStakeMaturity = block.timestamp + stakeDurationInDays*SECONDS_IN_DAY;

        require(timestampForStakeMaturity > block.timestamp, "maturity timestamp should be greater than block timestamp" );

        uint256 formattedStakeAmountWei = _adjustedWeiAmount(stakeAmountInWei, stakeTokenDecimal);
        
        require(formattedStakeAmountWei > 0, "Formatted stake amount invalid");
        
        uint256 rewardAtMaturityWei = _adjustedWeiAmount(_rewardAtMaturityWei( stakeDurationInDays, APRWei, formattedStakeAmountWei),rewardTokenDecimal);
        
        require(rewardAtMaturityWei > 0, "zero reward");

        require(rewardAtMaturityWei <= _remainingRewardInPoolWei(poolID), "Insufficient rewards");

        bytes memory userStakeKey = _generateStakeKey(poolID, msg.sender);
        if (_AllStakes[userStakeKey].stakeExists) {
            uint256 stakeDurationAtAddStakeDays = (block.timestamp - _AllStakes[userStakeKey].stakeTimestamp) / SECONDS_IN_DAY;
            uint256 earnedRewardAtAddStakeWei = _adjustedWeiAmount(
                _rewardAtMaturityWei(
                    stakeDurationAtAddStakeDays,
                    APRWei,
                    _AllStakes[userStakeKey].stakeAmountInWei
                ), rewardTokenDecimal
            );

            rewardAtMaturityWei += earnedRewardAtAddStakeWei;
            require( rewardAtMaturityWei <= _remainingRewardInPoolWei(poolID),"invalid reward/ insufficient reward balance"
            );

            _AllStakes[userStakeKey].stakeAmountInWei += formattedStakeAmountWei;
            _AllStakes[userStakeKey].stakeTimestamp = block.timestamp;
            _AllStakes[userStakeKey].stakeMaturityTimestamp = timestampForStakeMaturity;
            _AllStakes[userStakeKey]
                .rewardAtMaturityWei += rewardAtMaturityWei;
        } else {
            _AllStakes[userStakeKey] = StakeConfig({
                stakeAmountInWei: formattedStakeAmountWei,
                stakeTimestamp: block.timestamp,
                stakeMaturityTimestamp: timestampForStakeMaturity,
                rewardAtMaturityWei: rewardAtMaturityWei,
                rewardClaimedWei: 0,
                canClaimAndUnstake: true,
                stakeExists: true
            });
        }

        _StakingPoolSummary[poolID].totalStakedWei += formattedStakeAmountWei;
        _StakingPoolSummary[poolID]
            .rewardToBeDistributedWei += rewardAtMaturityWei;

        emit Staked(
            poolID,
            msg.sender,
            stakeTokenAddress,
            formattedStakeAmountWei,
            block.timestamp,
            timestampForStakeMaturity,
            _AllStakes[userStakeKey].rewardAtMaturityWei
        );


        _transferTokensToContract(
            stakeTokenAddress,
            stakeTokenDecimal,
            formattedStakeAmountWei,
            msg.sender
        );
    }

    /**
     * @inheritdoc IFactoryStaking
     */
    function claimPoolReward(bytes32 poolID) external override {
        (
            ,
            ,
            ,
            ,
            address rewardTokenAddress,
            uint256 rewardTokenDecimal,
            ,
            bool canClaimAndUnstake

        ) = _retrieveStakingPoolInformation(poolID);
        require(canClaimAndUnstake, "pool suspended");

        bytes memory userStakeKey = _generateStakeKey(poolID, msg.sender);

        require(_AllStakes[userStakeKey].stakeExists, "stake doesnt exist");
        require(_AllStakes[userStakeKey].canClaimAndUnstake, "stake suspended");
        require(_stakeMaturedByStakekey(userStakeKey), "stake is not mature");

        uint256 rewardAmountInWei = _claimableRewardWeiByStakekey(userStakeKey);
        require(rewardAmountInWei > 0, "zero reward");

        _StakingPoolSummary[poolID].totalRewardWei -= rewardAmountInWei;
        _StakingPoolSummary[poolID].rewardToBeDistributedWei -= rewardAmountInWei;
        _AllStakes[userStakeKey].rewardClaimedWei += rewardAmountInWei;

        emit RewardClaimed(
            poolID,
            msg.sender,
            rewardTokenAddress,
            rewardAmountInWei
        );

        _transferTokensToAccount(
            rewardTokenAddress,
            rewardTokenDecimal,
            rewardAmountInWei,
            msg.sender
        );
    }

    /**
     * @inheritdoc IFactoryStaking
     */
    function unstake(bytes32 poolID) external override {
        (
            ,
            ,
            address stakeTokenAddress,
            uint256 stakeTokenDecimal,
            address rewardTokenAddress,
            uint256 rewardTokenDecimal,
            ,
            bool canClaimAndUnstake

        ) = _retrieveStakingPoolInformation(poolID);
        require(canClaimAndUnstake, "pool suspended");

        bytes memory userStakeKey = _generateStakeKey(poolID, msg.sender);
        require(_AllStakes[userStakeKey].stakeExists, "Stake doesnt exist");
        require(_AllStakes[userStakeKey].canClaimAndUnstake, "stake suspended");
        require(_stakeMaturedByStakekey(userStakeKey), "Stake is not mature");

        uint256 stakeAmountInWei = _AllStakes[userStakeKey].stakeAmountInWei;
        require(stakeAmountInWei > 0, "no stake / zero");

        uint256 rewardAmountInWei = _claimableRewardWeiByStakekey(userStakeKey);

        _StakingPoolSummary[poolID].totalStakedWei -= stakeAmountInWei;
        _StakingPoolSummary[poolID].totalRewardWei -= rewardAmountInWei;
        _StakingPoolSummary[poolID].rewardToBeDistributedWei -= rewardAmountInWei;

        _AllStakes[userStakeKey] = StakeConfig({
            stakeAmountInWei: 0,
            stakeTimestamp: 0,
            stakeMaturityTimestamp: 0,
            rewardAtMaturityWei: 0,
            rewardClaimedWei: 0,
            canClaimAndUnstake: false,
            stakeExists: false
        });

        emit Unstaked(
            poolID,
            msg.sender,
            stakeTokenAddress,
            stakeAmountInWei,
            rewardTokenAddress,
            rewardAmountInWei
        );

        if (
            stakeTokenAddress == rewardTokenAddress &&
            stakeTokenDecimal == rewardTokenDecimal
        ) {
            _transferTokensToAccount(
                stakeTokenAddress,
                stakeTokenDecimal,
                stakeAmountInWei + rewardAmountInWei,
                msg.sender
            );
        } else {
            _transferTokensToAccount(
                stakeTokenAddress,
                stakeTokenDecimal,
                stakeAmountInWei,
                msg.sender
            );

            if (rewardAmountInWei > 0) {
                _transferTokensToAccount(
                    rewardTokenAddress,
                    rewardTokenDecimal,
                    rewardAmountInWei,
                    msg.sender
                );
            }
        }
    }


    /**
     * @inheritdoc IFactoryStaking
     */
    function addStakingPoolReward(bytes32 poolID, uint256 rewardAmountInWei)
        external
        override
        onlyRole(CONTRACT_ADMIN_ROLE)
    {
        require(rewardAmountInWei > 0, "zero / invalid reward amount");

        (
        ,
        ,
        ,
        ,
        address rewardTokenAddress,
        uint256 rewardTokenDecimal,
        ,

        ) = _retrieveStakingPoolInformation(poolID);

        uint256 formattedRewardAmountWei = rewardTokenDecimal <
            TOKEN_MAX_DECIMALS
            ? _convertWeiToDecimals(
                _convertDecimalsToWei(rewardAmountInWei, rewardTokenDecimal),
                rewardTokenDecimal)
            : rewardAmountInWei;

        _StakingPoolSummary[poolID].totalRewardWei += formattedRewardAmountWei;

        emit StakingPoolRewardAdded(
            poolID,
            msg.sender,
            rewardTokenAddress,
            formattedRewardAmountWei
        );

        _transferTokensToContract(
            rewardTokenAddress,
            rewardTokenDecimal,
            formattedRewardAmountWei,
            msg.sender
        );
    }

    /**
     * @inheritdoc IFactoryStaking
     */
    function getStakingPoolSummary(bytes32 poolID)
        external
        view
        override
        returns (
            uint256 totalRewardWei,
            uint256 totalStakedWei,
            uint256 rewardToBeDistributedWei,
            uint256 poolSizeWei,
            bool isOpen,
            bool canClaimAndUnstake

        )
    {
        uint256 stakeDurationInDays;
        uint256 stakeTokenDecimal;
        uint256 APRWei;

        (
            stakeDurationInDays,
            APRWei,
            ,
            stakeTokenDecimal,
            ,
            ,
            isOpen,
            canClaimAndUnstake
        ) = _retrieveStakingPoolInformation(poolID);

        poolSizeWei = _adjustedWeiAmount(
            (DAYS_IN_YEAR * PERCENT_100_WEI * totalRewardWei) / (stakeDurationInDays * APRWei),
            stakeTokenDecimal
        );

        totalRewardWei = _StakingPoolSummary[poolID].totalRewardWei;
        totalStakedWei = _StakingPoolSummary[poolID].totalStakedWei;
        rewardToBeDistributedWei = _StakingPoolSummary[poolID].rewardToBeDistributedWei;
    }

    function retrieveStakeInfo(bytes32 poolID, address account)
        external
        view
        override
        returns (
            uint256 stakeAmountInWei,
            uint256 stakeTimestamp,
            uint256 stakeMaturityTimestamp,
            uint256 rewardAtStakeMaturityWei,
            uint256 rewardClaimedWei,
            bool canClaimAndUnstake
        )
    {
        bytes memory userStakeKey = _generateStakeKey(poolID, account);
        require(_AllStakes[userStakeKey].canClaimAndUnstake, "SSvcs: uninitialized");

        stakeAmountInWei = _AllStakes[userStakeKey].stakeAmountInWei;
        stakeTimestamp = _AllStakes[userStakeKey].stakeTimestamp;
        stakeMaturityTimestamp = _AllStakes[userStakeKey].stakeMaturityTimestamp;
        rewardAtStakeMaturityWei = _AllStakes[userStakeKey]
            .rewardAtMaturityWei;
        rewardClaimedWei = _AllStakes[userStakeKey].rewardClaimedWei;
        canClaimAndUnstake = _AllStakes[userStakeKey].canClaimAndUnstake;
    }



    /**
     * @dev Transfers tokens from the user's account to the contract.
     * @param tokenAddress Address of the ERC20 token.
     * @param tokenDecimal Decimals of the ERC20 token.
     * @param amountInWei Amount in Wei to transfer.
     * @param account Address of the user's account.
     */
    function _transferTokensToContract(
        address tokenAddress,
        uint256 tokenDecimal,
        uint256 amountInWei,
        address account
    ) internal {
        require(tokenAddress != address(0),  "invalid token address");
        require(tokenDecimal <= TOKEN_MAX_DECIMALS, "invalid token decimals");
        require(amountInWei > 0, "invalid amount");
        require(account != address(0),"invalid account address");

        uint256 amountDecimal = _convertWeiToDecimals(amountInWei,tokenDecimal);

        IERC20(tokenAddress).safeTransferFrom(
            account,
            address(this),
            amountDecimal
        );
    }

    /**
     * @dev Transfers tokens from the contract to the user's account.
     * @param tokenAddress Address of the ERC20 token.
     * @param tokenDecimal Decimals of the ERC20 token.
     * @param amountWei Amount in Wei to transfer.
     * @param account Address of the user's account.
     */
    function _transferTokensToAccount(
        address tokenAddress,
        uint256 tokenDecimal,
        uint256 amountWei,
        address account
    ) internal  {
        require(tokenAddress != address(0), "invalid token address");
        require(tokenDecimal <= TOKEN_MAX_DECIMALS, "invalid token decimals");
        require(amountWei > 0, "invalid amount");
        require(account != address(0), "invalid account address");

        uint256 amountDecimal = _convertWeiToDecimals(amountWei, tokenDecimal);

        IERC20(tokenAddress).safeTransfer(account, amountDecimal);
    }


    /**
     * @dev Retrieves staking pool information from the staking pool contract.
     * @param poolID Identifier of the staking pool.
     * @return stakeDurationInDays Stake duration in days.
     * @return APRWei Annual Percentage Rate in Wei.
     * @return stakeTokenAddress Address of the staked token.
     * @return stakeTokenDecimal Decimals of the staked token.
     * @return rewardTokenAddress Address of the reward token.
     * @return rewardTokenDecimal Decimals of the reward token.
     * @return isOpen Boolean indicating whether the staking pool is open.
     * @return canClaimAndUnstake Boolean indicating whether claiming and unstaking are allowed.
     */
    function _retrieveStakingPoolInformation(bytes32 poolID) internal view returns(
        uint256 stakeDurationInDays,
        uint256 APRWei,
        address stakeTokenAddress,
        uint256 stakeTokenDecimal,
        address rewardTokenAddress,
        uint256 rewardTokenDecimal,
        bool isOpen,
        bool canClaimAndUnstake
    ) {
        (
            stakeDurationInDays,
            APRWei,
            stakeTokenAddress,
            stakeTokenDecimal,
            rewardTokenAddress,
            rewardTokenDecimal,
            isOpen,
            canClaimAndUnstake
        ) = IStakingPool(stakingPoolContract).retrieveStakingPoolInformation(poolID);
    }

    function _getStakingPoolConfig(bytes32 poolID) internal view returns (
        uint256 maxPoolSize
    ) {
        return IStakingPool(stakingPoolContract).getStakingPoolMaxPoolSize(poolID);
    }

    /**
     * @dev Converts an amount in Wei to its equivalent in specified decimals.
     * @param amountInWei Amount in Wei to convert.
     * @param decimals Decimals to convert to.
     * @return decimalsAmount Equivalent amount in specified decimals.
     */
    function _convertWeiToDecimals(uint256 amountInWei, uint256 decimals) internal pure returns (uint256 decimalsAmount)
    {
        require(decimals <= TOKEN_MAX_DECIMALS, "CustomUnitConverter: Invalid decimals");

        if (decimals < TOKEN_MAX_DECIMALS && amountInWei > 0) {
            uint256 decimalsDiff = TOKEN_MAX_DECIMALS - decimals;
            decimalsAmount = amountInWei / 10**decimalsDiff;
        } else {
            decimalsAmount = amountInWei;
        }
    }

    /**
     * @dev Converts an amount in specified decimals to its equivalent in Wei.
     * @param decimalsAmount Amount in specified decimals to convert.
     * @param decimals Decimals of the amount.
     * @return weiAmount Equivalent amount in Wei.
     */
    function _convertDecimalsToWei(uint256 decimalsAmount, uint256 decimals) internal pure returns (uint256 weiAmount)
    {
        require(decimals <= TOKEN_MAX_DECIMALS, "CustomUnitConverter: Invalid decimals");

        if (decimals < TOKEN_MAX_DECIMALS && decimalsAmount > 0) {
            uint256 decimalsDiff = TOKEN_MAX_DECIMALS - decimals;
            weiAmount = decimalsAmount * 10**decimalsDiff;
        } else {
            weiAmount = decimalsAmount;
        }
    }

    /**
     * @dev Adjusts the amount in Wei based on token decimals.
     * @param amountWei Amount in Wei to adjust.
     * @param tokenDecimal Decimals of the token.
     * @return adjustedWeiAmount Adjusted amount in Wei.
     */
    function _adjustedWeiAmount(uint256 amountWei, uint256 tokenDecimal) internal pure returns (uint256 adjustedWeiAmount)
    {
        adjustedWeiAmount = tokenDecimal < TOKEN_MAX_DECIMALS
            ? _convertWeiToDecimals(_convertDecimalsToWei(amountWei,tokenDecimal), tokenDecimal): amountWei;
    }

    /**
     * @dev Calculates the remaining reward in the staking pool in Wei.
     * @param poolID Identifier of the staking pool.
     * @return remainingRewardInPoolWei Remaining reward in Wei.
     */
    function _remainingRewardInPoolWei(bytes32 poolID) internal view returns (uint256 remainingRewardInPoolWei)
    {
        remainingRewardInPoolWei = _StakingPoolSummary[poolID].totalRewardWei -_StakingPoolSummary[poolID].rewardToBeDistributedWei;
    }

    /**
     * @dev Calculates the reward at maturity based on stake information.
     * @param stakeDurationInDays Duration of the stake in days.
     * @param APRWei Annual Percentage Rate in Wei.
     * @param stakeAmountInWei Amount staked in Wei.
     * @return rewardAtMaturityWei Reward at maturity in Wei.
     */
    function _rewardAtMaturityWei(
        uint256 stakeDurationInDays,
        uint256 APRWei,
        uint256 stakeAmountInWei
    ) internal pure returns (uint256 rewardAtMaturityWei) {
        rewardAtMaturityWei =
            (APRWei * stakeDurationInDays * stakeAmountInWei) /
            (DAYS_IN_YEAR * PERCENT_100_WEI);
    }

    /**
     * @dev Generates a unique key for a stake using the pool ID and user account.
     * @param poolID Identifier of the staking pool.
     * @param userAccount Address of the user's account.
     * @return userStakeKey Unique key for the stake.
     */
    function _generateStakeKey(bytes32 poolID, address userAccount) internal pure returns (bytes memory userStakeKey)
    {
        require(userAccount != address(0), "SSvcs: account");

        userStakeKey = abi.encode(userAccount, poolID);
    }

    /**
     * @dev Checks if a stake has matured based on the stake key.
     * @param userStakeKey Stake key.
     * @return Boolean indicating whether the stake has matured.
     */
    function _stakeMaturedByStakekey(bytes memory userStakeKey) internal view returns (bool)
    {
        return
            _AllStakes[userStakeKey].stakeMaturityTimestamp > 0 && block.timestamp >= _AllStakes[userStakeKey].stakeMaturityTimestamp;
    }


    /**
     * @dev Calculates the claimable reward in Wei based on the stake key.
     * @param userStakeKey Stake key.
     * @return claimableRewardWei Claimable reward in Wei.
     */
    function _claimableRewardWeiByStakekey(bytes memory userStakeKey) internal view returns (uint256 claimableRewardWei)
    {
        if (!_AllStakes[userStakeKey].canClaimAndUnstake) {
            return 0;
        }

        if (_stakeMaturedByStakekey(userStakeKey)) {
            claimableRewardWei =
                _AllStakes[userStakeKey].rewardAtMaturityWei -
                _AllStakes[userStakeKey].rewardClaimedWei;
        } else {
            claimableRewardWei = 0;
        }
    }

}