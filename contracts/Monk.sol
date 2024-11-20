// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ERC20.sol";
import "./Ownable.sol";

/**
 * @title Monk
 * @author MonkeyBrothers
 * @notice The ERC20 token used as currency in the Monkey Brothers game
 * @dev Implements ERC20 standard with additional game-specific functionality
 */
contract Monk is ERC20("MONK", "MK"), Ownable {
    /// @notice Maximum total supply limit of MONK tokens
    uint256 supplyLimit;

    /// @notice Current circulating supply of MONK tokens
    uint256 currentSupply;

    /**
     * @notice Initializes the MONK token contract with supply limit
     * @dev Sets supply limit to 1 million tokens with 18 decimals
     */
    constructor() {
        supplyLimit = 1000000 * 1000000000000000000;
    }

    /**
     * @notice Allows users to mint MONK tokens by sending ETH
     * @dev Mints tokens at a 1:1000 ratio with ETH
     */
    function getMonks() public payable {
        uint256 amt = msg.value * 1000;
        require(
            totalSupply() + amt < supplyLimit,
            "Warning: Insufficient Monks!"
        );
        _mint(msg.sender, amt);
    }

    /**
     * @notice Retrieves the MONK balance of the caller in whole tokens
     * @dev Converts balance from 18 decimals to whole tokens
     * @return uint256 Balance in whole MONK tokens
     */
    function checkMonks() public view returns (uint256) {
        return balanceOf(msg.sender) / 1000000000000000000;
    }

    /**
     * @notice Retrieves the MONK balance of a specified address in whole tokens
     * @dev Converts balance from 18 decimals to whole tokens
     * @param user Address to check balance of
     * @return uint256 Balance in whole MONK tokens
     */
    function checkMonksOf(address user) public view returns (uint256) {
        return balanceOf(user) / 1000000000000000000;
    }

    /**
     * @notice Transfers whole MONK tokens to a recipient
     * @dev Converts whole tokens to 18 decimal format before transfer
     * @param recipient Address to receive tokens
     * @param value Amount of whole tokens to transfer
     * @return bool Success of transfer operation
     */
    function transferMonks(
        address recipient,
        uint256 value
    ) public returns (bool) {
        return transfer(recipient, value * 1000000000000000000);
    }

    /**
     * @notice Transfers tokens from one address to another using allowance
     * @dev Converts whole tokens to 18 decimal format before transfer
     * @param from Address to transfer from
     * @param to Address to transfer to
     * @param amt Amount of whole tokens to transfer
     */
    function transferMonksFrom(address from, address to, uint256 amt) public {
        require(
            allowance(from, msg.sender) > amt * 1000000000000000000,
            "Warning: You are not allowed to transfer!"
        );
        transferFrom(from, to, amt * 1000000000000000000);
    }

    /**
     * @notice Approves an address to spend tokens on behalf of the caller
     * @dev Converts whole tokens to 18 decimal format for allowance
     * @param recipient Address to be approved
     * @param amt Amount of whole tokens to approve
     */
    function giveMonkApproval(address recipient, uint256 amt) public {
        approve(recipient, amt * 1000000000000000000);
    }

    /**
     * @notice Checks the token allowance in whole tokens
     * @dev Converts allowance from 18 decimals to whole tokens
     * @param user Address of token owner
     * @param spender Address of approved spender
     * @return uint256 Allowance in whole tokens
     */
    function checkMonkAllowance(
        address user,
        address spender
    ) public view returns (uint256) {
        return allowance(user, spender) / 1000000000000000000;
    }

    /**
     * @notice Gets the current total supply in whole tokens
     * @dev Converts total supply from 18 decimals to whole tokens
     * @return uint256 Total supply in whole tokens
     */
    function currentMonkSupply() public view returns (uint256) {
        return totalSupply() / 1000000000000000000;
    }
}
