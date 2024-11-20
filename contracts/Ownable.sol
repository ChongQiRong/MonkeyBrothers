// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Ownable
 * @author MonkeyBrothers
 * @notice Contract module which provides basic access control mechanism with ownership
 * @dev Contract ownership facilitates authorization and privileged operations
 */
contract Ownable {
    /// @notice Address of the contract owner
    /// @dev Initialized to msg.sender in constructor
    address private _owner;

    /**
     * @notice Emitted when ownership is transferred
     * @param previousOwner Address of the previous owner
     * @param newOwner Address of the new owner
     */
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @notice Initializes the contract with msg.sender as owner
     * @dev Sets the original owner of contract when it is deployed
     */
    constructor() {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /**
     * @notice Returns the address of the current owner
     * @return address Current owner's address
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @notice Throws if called by any account other than the owner
     * @dev Modifier to restrict function access to contract owner only
     */
    modifier onlyOwner() {
        require(isOwner(), "Function accessible only by the owner !!");
        _;
    }

    /**
     * @notice Checks if the caller is the current owner
     * @dev Public function to verify ownership
     * @return bool True if caller is the owner, false otherwise
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }
}
