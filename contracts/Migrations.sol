// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Migrations
 * @notice Truffle migration management contract
 * @dev Handles deployment versioning managed by Truffle
 */
contract Migrations {
    /// @notice Address of the contract owner
    address public owner;
    /// @notice Last completed migration timestamp
    uint256 public last_completed_migration;

    /**
     * @notice Ensures only owner can call the function
     */
    modifier restricted() {
        if (msg.sender == owner) _;
    }

    /**
     * @notice Sets the original owner of contract during deployment
     */
    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice Sets the last completed migration number
     * @param completed Migration number completed
     */
    function setCompleted(uint completed) public restricted {
        last_completed_migration = completed;
    }

    /**
     * @notice Upgrades the contract to a new address
     * @param new_address Address of the new migrations contract
     */
    function upgrade(address new_address) public restricted {
        Migrations upgraded = Migrations(new_address);
        upgraded.setCompleted(last_completed_migration);
    }
}
