pragma solidity ^0.5.0;

/**
 * @title Player Details
 * @dev Stores player's level and experience
 */
contract PlayerDetails {
    address owner;
    uint public level;
    uint public exp;
    uint public constant maxLevel = 100;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    constructor() public {
        owner = msg.sender;
        level = 1;
        exp = 0;
    }

    /**
     * @dev Increases the player's experience by a given amount
     * @param _exp The amount of experience to add
     */
    function addExperience(uint _exp) public onlyOwner {
        exp += _exp;
        _updateLevel();
    }

    /**
     * @dev Updates the player's level based on the current experience
     */
    function _updateLevel() internal {
        while (exp >= requiredExpForNextLevel() && level < maxLevel) {
            exp -= requiredExpForNextLevel();
            level++;
        }
    }

    /**
     * @dev Returns the experience required for the next level
     * @return The required experience for next level
     */
    function requiredExpForNextLevel() public view returns (uint) {
        return level * 100;
    }
}
