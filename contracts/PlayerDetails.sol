// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Player Details
 * @dev Stores player's level and experience
 */
contract PlayerDetails {
    address owner;
    address public arenaContract;

    // Mapping of player address to their details
    mapping(address => PlayerData) private players;
    uint public constant maxLevel = 100;

    struct PlayerData {
        uint level;
        uint exp;
    }

    modifier onlyAuthorized() {
        require(
            msg.sender == owner || msg.sender == arenaContract,
            "Not authorized to perform this action"
        );
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setArenaContract(address _arenaContract) external onlyOwner {
        require(_arenaContract != address(0), "Invalid arena address");
        arenaContract = _arenaContract;
    }

    /**
     * @dev Increases the player's experience by a given amount
     * @param player The address of the player
     * @param _exp The amount of experience to add
     */
    function addExperience(address player, uint _exp) public onlyAuthorized {
        // Initialize player if first time
        if (players[player].level == 0) {
            players[player].level = 1;
        }

        players[player].exp += _exp;
        _updateLevel(player);
    }

    /**
     * @dev Updates the player's level based on the current experience
     */
    function _updateLevel(address player) internal {
        while (
            players[player].exp >= requiredExpForNextLevel(player) &&
            players[player].level < maxLevel
        ) {
            players[player].exp -= requiredExpForNextLevel(player);
            players[player].level++;
        }
    }

    /**
     * @dev Returns the experience required for the next level
     * @return The required experience for next level
     */
    function requiredExpForNextLevel(
        address player
    ) public view returns (uint) {
        return players[player].level * 100;
    }

    /**
     * @dev Get player's current level
     */
    function getPlayerLevel(address player) public view returns (uint) {
        return players[player].level;
    }

    /**
     * @dev Get player's current experience
     */
    function getPlayerExp(address player) public view returns (uint) {
        return players[player].exp;
    }
}
