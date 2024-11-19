// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ERC20.sol";
import "./Ownable.sol";

/**
 * @title Monk
 * @dev Monk is the ERC20 token used for Monkey Brothers
 */
contract Monk is ERC20("MONK", "MK"), Ownable {
    uint256 supplyLimit;
    uint256 currentSupply;

    /**
     * @dev Sets the values for owner of the contract and supply limit
     */
    constructor() {
        supplyLimit = 1000000 * 1000000000000000000;
    }

    /**
     * @dev Mints Monks with ETH
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
     * @dev Getter for amount of Monks held by the caller of the function
     */
    function checkMonks() public view returns (uint256) {
        return balanceOf(msg.sender) / 1000000000000000000;
    }

    /**
     * @dev Getter for amount of Monks held by an address
     * @param user Address of user of interest
     */
    function checkMonksOf(address user) public view returns (uint256) {
        return balanceOf(user) / 1000000000000000000;
    }

    /**
     * @dev Transfer Monks from function caller to recipient
     * @param recipient Address of recipient
     * @param value Amount of Monks to transfer
     */
    function transferMonks(
        address recipient,
        uint256 value
    ) public returns (bool) {
        return transfer(recipient, value * 1000000000000000000);
    }

    /**
     * @dev Transfer Monks from an address to another address
     * @param from Address of sender
     * @param to Address of recipient
     * @param amt Amount of Monks to transfer
     */
    function transferMonksFrom(address from, address to, uint256 amt) public {
        require(
            allowance(from, msg.sender) > amt * 1000000000000000000,
            "Warning: You are not allowed to transfer!"
        );
        transferFrom(from, to, amt * 1000000000000000000);
    }

    /**
     * @dev Give an address approval to transfer a specified amount of Monks
     * @param recipient Address to be given approval
     * @param amt Amount of Monks to be approved to the address
     */
    function giveMonkApproval(address recipient, uint256 amt) public {
        approve(recipient, amt * 1000000000000000000);
    }

    /**
     * @dev Check allowance given to spender by the user
     * @param user Address of the owner of the Monks
     * @param spender Address of the spender of the Monks
     */
    function checkMonkAllowance(
        address user,
        address spender
    ) public view returns (uint256) {
        return allowance(user, spender) / 1000000000000000000;
    }

    /**
     * @dev Track current total Monk supply
     */
    function currentMonkSupply() public view returns (uint256) {
        return totalSupply() / 1000000000000000000;
    }
}
