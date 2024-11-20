// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Ownable.sol";

/**
 * @title PlayerDetails
 * @author MonkeyBrothers
 * @notice Manages player progression and statistics
 * @dev Tracks experience points and levels for all players
 */
contract PlayerDetails is Ownable {
    /// @notice Address of the Arena contract authorized to update player stats
    address public arenaContract;

    /// @notice Maximum achievable player level
    uint public constant maxLevel = 100;

    /// @notice Mapping of player addresses to their progression data
    mapping(address => PlayerData) private players;

    /**
     * @notice Structure containing player progression data
     * @param level Current level of the player
     * @param exp Current experience points of the player
     */
    struct PlayerData {
        uint level;
        uint exp;
    }

    /// @notice Emitted when Arena contract address is updated
    /// @param oldArena Previous Arena contract address
    /// @param newArena New Arena contract address
    event ArenaContractUpdated(
        address indexed oldArena,
        address indexed newArena
    );

    /// @notice Emitted when a player gains experience
    /// @param player Address of the player
    /// @param amount Amount of experience gained
    /// @param newTotal New total experience
    event ExperienceGained(address indexed player, uint amount, uint newTotal);

    /// @notice Emitted when a player levels up
    /// @param player Address of the player
    /// @param newLevel New level achieved
    event LevelUp(address indexed player, uint newLevel);

    /**
     * @notice Restricts function access to owner or Arena contract
     */
    modifier onlyAuthorized() {
        require(
            msg.sender == owner() || msg.sender == arenaContract,
            "Not authorized to perform this action"
        );
        _;
    }

    /**
     * @notice Sets the address of the Arena contract
     * @dev Only callable by contract owner
     * @param _arenaContract Address of the new Arena contract
     */
    function setArenaContract(address _arenaContract) external onlyOwner {
        require(_arenaContract != address(0), "Invalid arena address");
        address oldArena = arenaContract;
        arenaContract = _arenaContract;
        emit ArenaContractUpdated(oldArena, _arenaContract);
    }

    /**
     * @notice Adds experience points to a player's total
     * @dev Automatically handles level ups and initializes new players
     * @param player Address of the player receiving experience
     * @param _exp Amount of experience points to add
     */
    function addExperience(address player, uint _exp) public onlyAuthorized {
        // Initialize player if first time
        if (players[player].level == 0) {
            players[player].level = 1;
        }

        players[player].exp += _exp;
        emit ExperienceGained(player, _exp, players[player].exp);
        _updateLevel(player);
    }

    /**
     * @notice Updates player level based on current experience
     * @dev Internal function that handles level progression
     * @param player Address of the player to update
     */
    function _updateLevel(address player) internal {
        while (
            players[player].exp >= requiredExpForNextLevel(player) &&
            players[player].level < maxLevel
        ) {
            players[player].exp -= requiredExpForNextLevel(player);
            players[player].level++;
            emit LevelUp(player, players[player].level);
        }
    }

    /**
     * @notice Calculates experience required for player's next level
     * @dev Experience requirement increases linearly with level
     * @param player Address of the player to check
     * @return uint Amount of experience required for next level
     */
    function requiredExpForNextLevel(
        address player
    ) public view returns (uint) {
        return players[player].level * 100;
    }

    /**
     * @notice Retrieves the current level of a player
     * @param player Address of the player to query
     * @return uint Current level of the player
     */
    function getPlayerLevel(address player) public view returns (uint) {
        return players[player].level;
    }

    /**
     * @notice Retrieves the current experience points of a player
     * @param player Address of the player to query
     * @return uint Current experience points of the player
     */
    function getPlayerExp(address player) public view returns (uint) {
        return players[player].exp;
    }

    /**
     * @notice Retrieves complete player progression data
     * @param player Address of the player to query
     * @return PlayerData Struct containing level and experience data
     */
    function getPlayerData(
        address player
    ) external view returns (PlayerData memory) {
        return players[player];
    }

    /**
     * @notice Checks if a player has reached maximum level
     * @param player Address of the player to check
     * @return bool True if player is at max level
     */
    function isMaxLevel(address player) external view returns (bool) {
        return players[player].level >= maxLevel;
    }

    /**
     * @notice Calculates experience points remaining until next level
     * @param player Address of the player to check
     * @return uint Experience points needed for next level
     */
    function expToNextLevel(address player) external view returns (uint) {
        if (players[player].level >= maxLevel) return 0;
        return requiredExpForNextLevel(player) - players[player].exp;
    }
}
