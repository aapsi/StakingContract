// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title StakeToken
 * @dev A simple ERC-20 token representing staking tokens.
 * @notice This contract mints an initial supply of staking tokens to the contract deployer.
 */
contract StakeToken is ERC20 {

    constructor() ERC20("Stake", "STK") {
        _mint(msg.sender, 1000000000000 * 10 ** 18);
    }

}
