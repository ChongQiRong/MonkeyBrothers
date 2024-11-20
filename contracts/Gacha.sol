// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Ownable.sol";
import "./Monk.sol";
import "./Monkey.sol";

/**
 * @title MonkeyGacha
 * @author MonkeyBrothers
 * @notice This contract implements a gacha system for minting Monkey NFTs
 * @dev Handles random Monkey generation with different rarities and attributes
 */
contract MonkeyGacha is Ownable {
    Monk public monkToken;
    Monkeys public monkeyNFT;

    /// @notice Chance of drawing Common rarity (55%)
    uint16 public COMMON_CHANCE = 5500;
    /// @notice Chance of drawing Rare rarity (25%)
    uint16 public RARE_CHANCE = 2500;
    /// @notice Chance of drawing Epic rarity (15%)
    uint16 public EPIC_CHANCE = 1500;
    /// @notice Chance of drawing Legendary rarity (5%)
    uint16 public LEGENDARY_CHANCE = 500;

    /// @notice Cost of a single gacha draw in Monk tokens
    uint256 public constant GACHA_PRICE = 1 ether;
    /// @notice Cost of starter pack in Monk tokens
    uint256 public constant STARTER_PACK_PRICE = 5 ether;

    /**
     * @notice Structure defining stat ranges for each rarity
     * @param minAttack Minimum attack value
     * @param maxAttack Maximum attack value
     * @param minHealth Minimum health value
     * @param maxHealth Maximum health value
     */
    struct StatRange {
        uint256 minAttack;
        uint256 maxAttack;
        uint256 minHealth;
        uint256 maxHealth;
    }

    /**
     * @notice Structure for storing name pools for each power type
     * @param firstNames Array of possible first names
     * @param lastNames Array of possible last names
     */
    struct TypeNames {
        string[] firstNames;
        string[] lastNames;
    }

    /// @notice Maps rarity levels to their stat ranges
    /// @dev Key is uint8 representation of Rarity enum
    mapping(uint8 => StatRange) public rarityStats;

    /// @notice Tracks which addresses have claimed their starter pack
    /// @dev Prevents multiple claims by the same address
    mapping(address => bool) public hasClaimedStarterPack;

    /// @notice Stores name pools for each power type
    /// @dev Key is uint8 representation of PowerType enum
    mapping(uint8 => TypeNames) private typeNames;

    /// @notice Emitted when a new Monkey is drawn from gacha
    /// @param player Address of the player who drew the Monkey
    /// @param tokenId ID of the newly minted Monkey
    /// @param rarity Rarity level of the Monkey
    /// @param powerType Element type of the Monkey
    /// @param attack Attack stat of the Monkey
    /// @param health Health stat of the Monkey
    /// @param name Generated name of the Monkey
    event MonkeyDrawn(
        address indexed player,
        uint256 indexed tokenId,
        uint8 rarity,
        uint8 powerType,
        uint256 attack,
        uint256 health,
        string name
    );

    /// @notice Emitted when a starter pack is claimed
    /// @param player Address of the player claiming the pack
    /// @param monkeyIds Array of token IDs for the claimed Monkeys
    event StarterPackClaimed(address indexed player, uint256[] monkeyIds);

    /// @notice Emitted when accumulated tokens are withdrawn
    /// @param owner Address receiving the tokens
    /// @param amount Amount of tokens withdrawn
    /// @param timestamp Time of withdrawal
    event TokensWithdrawn(
        address indexed owner,
        uint256 amount,
        uint256 timestamp
    );

    /// @notice Emitted when stat ranges for a rarity are updated
    /// @param rarity Rarity level being updated
    /// @param minAttack New minimum attack value
    /// @param maxAttack New maximum attack value
    /// @param minHealth New minimum health value
    /// @param maxHealth New maximum health value
    event StatRangeUpdated(
        uint8 indexed rarity,
        uint256 minAttack,
        uint256 maxAttack,
        uint256 minHealth,
        uint256 maxHealth
    );

    /// @notice Emitted when rarity chances are updated
    /// @param commonChance New chance for Common rarity
    /// @param rareChance New chance for Rare rarity
    /// @param epicChance New chance for Epic rarity
    /// @param legendaryChance New chance for Legendary rarity
    event RarityOddsUpdated(
        uint16 commonChance,
        uint16 rareChance,
        uint16 epicChance,
        uint16 legendaryChance
    );

    /// @notice Emitted when new names are added to a power type's pool
    /// @param powerType Element type receiving new names
    /// @param firstNamesAdded Number of first names added
    /// @param lastNamesAdded Number of last names added
    event NamesAdded(
        uint8 powerType,
        uint256 firstNamesAdded,
        uint256 lastNamesAdded
    );

    /**
     * @notice Initializes the MonkeyGacha contract with token contracts and default stat ranges
     * @dev Sets up initial stat ranges for all rarity levels
     * @param _monkToken Address of the MONK token contract
     * @param _monkeyNFT Address of the Monkey NFT contract
     */
    constructor(address _monkToken, address _monkeyNFT) {
        require(
            _monkToken != address(0) && _monkeyNFT != address(0),
            "Invalid addresses"
        );

        monkToken = Monk(_monkToken);
        monkeyNFT = Monkeys(_monkeyNFT);

        // Initialize stat ranges
        rarityStats[uint8(Monkeys.Rarity.Common)] = StatRange(5, 15, 40, 50);
        rarityStats[uint8(Monkeys.Rarity.Rare)] = StatRange(11, 20, 50, 59);
        rarityStats[uint8(Monkeys.Rarity.Epic)] = StatRange(16, 25, 65, 74);
        rarityStats[uint8(Monkeys.Rarity.Legendary)] = StatRange(
            26,
            35,
            85,
            94
        );
    }

    /**
     * @notice Allows players to claim a starter pack of Monkeys
     * @dev Creates three Common Monkeys of different types
     */
    function claimStarterPack() external {
        require(
            !hasClaimedStarterPack[msg.sender],
            "Starter pack already claimed"
        );
        require(
            monkToken.balanceOf(msg.sender) >= STARTER_PACK_PRICE,
            "Insufficient MONK balance"
        );
        require(
            monkToken.allowance(msg.sender, address(this)) >=
                STARTER_PACK_PRICE,
            "Insufficient MONK allowance"
        );

        // Transfer MONK tokens
        require(
            monkToken.transferFrom(
                msg.sender,
                address(this),
                STARTER_PACK_PRICE
            ),
            "Token transfer failed"
        );

        // Generate three monkeys (one of each type)
        uint256[] memory monkeyIds = new uint256[](3);
        for (uint8 i = 0; i < 3; i++) {
            // Generate balanced stats for starter monkeys
            uint256 attack = 10 + _random(6);
            uint256 health = 45 + _random(6);

            // MODIFIED: Now using type-specific name generation
            string memory name = _generateName(i);

            monkeyIds[i] = monkeyNFT.mintMonkey(
                msg.sender,
                name,
                uint8(Monkeys.Rarity.Common),
                i,
                attack,
                health
            );
        }

        hasClaimedStarterPack[msg.sender] = true;
        emit StarterPackClaimed(msg.sender, monkeyIds);
    }

    /**
     * @notice Allows players to draw a random Monkey
     * @dev Generates random attributes based on rarity chances
     */
    function drawMonkey() external {
        // Check if player has enough MONK tokens
        require(
            monkToken.balanceOf(msg.sender) >= GACHA_PRICE,
            "Insufficient MONK balance"
        );

        // Transfer MONK tokens from player
        require(
            monkToken.transferFrom(msg.sender, address(this), GACHA_PRICE),
            "Transfer failed"
        );

        // Generate random monkey attributes
        uint8 rarity = _determineRarity();
        uint8 powerType = uint8(_random(uint256(Monkeys.PowerType.Grass) + 1));
        string memory name = _generateName(powerType);

        // Generate stats based on rarity
        StatRange memory range = rarityStats[rarity];
        uint256 attack = _random(range.maxAttack - range.minAttack + 1) +
            range.minAttack;
        uint256 health = _random(range.maxHealth - range.minHealth + 1) +
            range.minHealth;

        // Mint new monkey NFT
        uint256 tokenId = monkeyNFT.mintMonkey(
            msg.sender,
            name,
            rarity,
            powerType,
            attack,
            health
        );

        emit MonkeyDrawn(
            msg.sender,
            tokenId,
            rarity,
            powerType,
            attack,
            health,
            name
        );
    }

    /**
     * @notice Checks if an address is eligible for starter pack
     * @param player Address to check
     * @return bool Whether the address can claim a starter pack
     */
    function canClaimStarterPack(address player) external view returns (bool) {
        return !hasClaimedStarterPack[player];
    }

    /**
     * @notice Determines the rarity of a new Monkey
     * @dev Uses random number to select rarity based on defined chances
     * @return uint8 Rarity level as uint8
     */
    function _determineRarity() internal view returns (uint8) {
        uint256 rand = _random(10000);

        if (rand < LEGENDARY_CHANCE) return uint8(Monkeys.Rarity.Legendary);
        if (rand < LEGENDARY_CHANCE + EPIC_CHANCE)
            return uint8(Monkeys.Rarity.Epic);
        if (rand < LEGENDARY_CHANCE + EPIC_CHANCE + RARE_CHANCE)
            return uint8(Monkeys.Rarity.Rare);
        return uint8(Monkeys.Rarity.Common);
    }

    /**
     * @notice Generates a pseudo-random number
     * @dev Uses block data and msg.sender for randomness
     * @param max Maximum value to generate
     * @return uint256 Random number between 0 and max-1
     */
    function _random(uint256 max) internal view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.prevrandao,
                        msg.sender,
                        block.number
                    )
                )
            ) % max;
    }

    /**
     * @notice Adds new names to the name pool for a power type
     * @dev Can initialize or append to existing name pools
     * @param powerType Element type to add names for
     * @param _firstNames Array of first names to add
     * @param _lastNames Array of last names to add
     */
    function addNamesForType(
        uint8 powerType,
        string[] calldata _firstNames,
        string[] calldata _lastNames
    ) external onlyOwner {
        require(
            powerType <= uint8(Monkeys.PowerType.Grass),
            "Invalid power type"
        );

        // Initialize arrays if empty
        if (typeNames[powerType].firstNames.length == 0) {
            typeNames[powerType].firstNames = _firstNames;
            typeNames[powerType].lastNames = _lastNames;
        } else {
            // Add to existing arrays
            for (uint i = 0; i < _firstNames.length; i++) {
                require(bytes(_firstNames[i]).length > 0, "Empty first name");
                typeNames[powerType].firstNames.push(_firstNames[i]);
            }

            for (uint i = 0; i < _lastNames.length; i++) {
                require(bytes(_lastNames[i]).length > 0, "Empty last name");
                typeNames[powerType].lastNames.push(_lastNames[i]);
            }
        }
    }

    /**
     * @notice Generates a random name for a Monkey
     * @dev Combines random first and last names from the power type's pool
     * @param powerType Element type to generate name for
     * @return string Generated full name
     */
    function _generateName(
        uint8 powerType
    ) internal view returns (string memory) {
        TypeNames storage names = typeNames[powerType];
        require(
            names.firstNames.length > 0 && names.lastNames.length > 0,
            "Names not initialized"
        );

        string memory firstName = names.firstNames[
            _random(names.firstNames.length)
        ];
        string memory lastName = names.lastNames[
            _random(names.lastNames.length)
        ];
        return string(abi.encodePacked(firstName, " ", lastName));
    }

    /**
     * @notice Gets the stat range for a specific rarity
     * @param rarity Rarity level to query
     * @return StatRange Struct containing stat ranges
     */
    function getStatRange(
        uint8 rarity
    ) external view returns (StatRange memory) {
        require(rarity <= uint8(Monkeys.Rarity.Legendary), "Invalid rarity");
        return rarityStats[rarity];
    }

    // Administrative functions
    /**
     * @notice Withdraws accumulated MONK tokens
     * @dev Only callable by contract owner
     */
    function withdrawTokens() external onlyOwner {
        uint256 balance = monkToken.balanceOf(address(this));
        require(monkToken.transfer(owner(), balance), "Transfer failed");
        emit TokensWithdrawn(owner(), balance, block.timestamp);
    }

    /**
     * @notice Updates the stat ranges for a rarity level
     * @dev Only callable by contract owner
     * @param rarity Rarity level to update
     * @param minAttack New minimum attack value
     * @param maxAttack New maximum attack value
     * @param minHealth New minimum health value
     * @param maxHealth New maximum health value
     */
    function setStatRange(
        uint8 rarity,
        uint256 minAttack,
        uint256 maxAttack,
        uint256 minHealth,
        uint256 maxHealth
    ) external onlyOwner {
        require(rarity <= uint8(Monkeys.Rarity.Legendary), "Invalid rarity");
        require(
            maxAttack >= minAttack && maxHealth >= minHealth,
            "Invalid range"
        );

        rarityStats[rarity] = StatRange(
            minAttack,
            maxAttack,
            minHealth,
            maxHealth
        );
        emit StatRangeUpdated(
            rarity,
            minAttack,
            maxAttack,
            minHealth,
            maxHealth
        );
    }

    /**
     * @notice Updates the chances for each rarity level
     * @dev Only callable by contract owner
     * @param _commonChance New chance for Common rarity
     * @param _rareChance New chance for Rare rarity
     * @param _epicChance New chance for Epic rarity
     * @param _legendaryChance New chance for Legendary rarity
     */
    function updateRarityOdds(
        uint16 _commonChance,
        uint16 _rareChance,
        uint16 _epicChance,
        uint16 _legendaryChance
    ) external onlyOwner {
        require(
            _commonChance + _rareChance + _epicChance + _legendaryChance ==
                10000,
            "Must total 100%"
        );

        COMMON_CHANCE = _commonChance;
        RARE_CHANCE = _rareChance;
        EPIC_CHANCE = _epicChance;
        LEGENDARY_CHANCE = _legendaryChance;

        emit RarityOddsUpdated(
            _commonChance,
            _rareChance,
            _epicChance,
            _legendaryChance
        );
    }

    /**
     * @notice Gets all names associated with a power type
     * @param powerType Element type to query
     * @return string[] Array of first names
     * @return string[] Array of last names
     */
    function getNamesForType(
        uint8 powerType
    ) external view returns (string[] memory, string[] memory) {
        require(
            powerType <= uint8(Monkeys.PowerType.Grass),
            "Invalid power type"
        );
        return (
            typeNames[powerType].firstNames,
            typeNames[powerType].lastNames
        );
    }
}
