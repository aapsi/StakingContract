# Multiple Reward Token Staking Contract Documentation

## Overview
This project implements a staking contract that allows users to stake ERC20 tokens and earn rewards in multiple ERC20 tokens. The contract is designed to be flexible and secure, leveraging OpenZeppelin's libraries for access control and token handling.

## Contracts

### 1. AdminOnly.sol
This contract extends OpenZeppelin's `AccessControl` to manage administrative roles. It defines a `CONTRACT_ADMIN_ROLE` that grants specific permissions to manage the staking pools.

### 2. ERC20_token_mock.sol
This contract is a simple ERC20 token implementation used for staking. It mints an initial supply of tokens to the contract deployer.

### 3. interfaces/IStakingPool.sol
This interface defines the functions and events for a staking pool contract. It includes methods for:
- Creating staking pools
- Opening and closing pools
- Disabling and enabling pools
- Retrieving pool information

### 4. interfaces/IFactoryStaking.sol
This interface defines the functions and events for a factory staking contract. It includes methods for:
- Creating staking pools
- Staking tokens
- Claiming rewards
- Unstaking tokens

### 5. StakingPool.sol
This contract implements the `IStakingPool` interface and manages the staking pools. It handles:
- Creation of staking pools
- Opening and closing of pools
- Enabling and disabling staking pools
- Retrieving staking pool information

### 6. FactoryStaking.sol
This contract implements the `IFactoryStaking` interface and manages the staking process. It allows users to:
- Stake tokens
- Claim rewards
- Unstake tokens
- Add rewards to staking pools

## Mock Values
The `mock_values.txt` file contains example values for testing the staking contract.

## Dependencies
This project uses OpenZeppelin contracts for access control and token handling. The dependencies are specified in the `package.json` file.

## .gitignore
The `.gitignore` file specifies files and directories that should be ignored by Git.

