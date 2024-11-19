// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Ownable.sol";
import "./Monk.sol";
import "./Monkey.sol";

contract MonkeyGacha is Ownable {
    Monk public monkToken;
    Monkeys public monkeyNFT;

    // Rarity chances (in basis points, 10000 = 100%)
    uint16 public COMMON_CHANCE = 5500; // 55%
    uint16 public RARE_CHANCE = 2500; // 25%
    uint16 public EPIC_CHANCE = 1500; // 15%
    uint16 public LEGENDARY_CHANCE = 500; // 5%

    // Costs
    uint256 public constant GACHA_PRICE = 1 ether; // 1 MONK token for regular draw
    uint256 public constant STARTER_PACK_PRICE = 5 ether; // 5 MONK tokens for starter pack

    // Stats ranges per rarity
    struct StatRange {
        uint256 minAttack;
        uint256 maxAttack;
        uint256 minHealth;
        uint256 maxHealth;
    }

    struct TypeNames {
        string[] firstNames;
        string[] lastNames;
    }

    mapping(uint8 => StatRange) public rarityStats;
    mapping(address => bool) public hasClaimedStarterPack;
    mapping(uint8 => TypeNames) private typeNames;

    event MonkeyDrawn(
        address indexed player,
        uint256 indexed tokenId,
        uint8 rarity,
        uint8 powerType,
        uint256 attack,
        uint256 health,
        string name
    );

    event StarterPackClaimed(address indexed player, uint256[] monkeyIds);

    event TokensWithdrawn(
        address indexed owner,
        uint256 amount,
        uint256 timestamp
    );

    event StatRangeUpdated(
        uint8 indexed rarity,
        uint256 minAttack,
        uint256 maxAttack,
        uint256 minHealth,
        uint256 maxHealth
    );

    event RarityOddsUpdated(
        uint16 commonChance,
        uint16 rareChance,
        uint16 epicChance,
        uint16 legendaryChance
    );

    event NamesAdded(
        uint8 powerType,
        uint256 firstNamesAdded,
        uint256 lastNamesAdded
    );

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
     * @dev Purchase a starter pack containing 3 Common Monkeys (one of each Type)
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
     * @dev Regular gacha draw for a single monkey
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
        uint8 powerType = uint8(_random(uint256(Monkeys.PowerType.Earth) + 1));
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
     * @dev Check if an address can claim a starter pack
     */
    function canClaimStarterPack(address player) external view returns (bool) {
        return !hasClaimedStarterPack[player];
    }

    function _determineRarity() internal view returns (uint8) {
        uint256 rand = _random(10000);

        if (rand < LEGENDARY_CHANCE) return uint8(Monkeys.Rarity.Legendary);
        if (rand < LEGENDARY_CHANCE + EPIC_CHANCE)
            return uint8(Monkeys.Rarity.Epic);
        if (rand < LEGENDARY_CHANCE + EPIC_CHANCE + RARE_CHANCE)
            return uint8(Monkeys.Rarity.Rare);
        return uint8(Monkeys.Rarity.Common);
    }

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

    function addNamesForType(
        uint8 powerType,
        string[] calldata _firstNames,
        string[] calldata _lastNames
    ) external onlyOwner {
        require(
            powerType <= uint8(Monkeys.PowerType.Earth),
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

    // View functions
    function getStatRange(
        uint8 rarity
    ) external view returns (StatRange memory) {
        require(rarity <= uint8(Monkeys.Rarity.Legendary), "Invalid rarity");
        return rarityStats[rarity];
    }

    // Administrative functions
    function withdrawTokens() external onlyOwner {
        uint256 balance = monkToken.balanceOf(address(this));
        require(monkToken.transfer(owner(), balance), "Transfer failed");
        emit TokensWithdrawn(owner(), balance, block.timestamp);
    }

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

    function getNamesForType(
        uint8 powerType
    ) external view returns (string[] memory, string[] memory) {
        require(
            powerType <= uint8(Monkeys.PowerType.Earth),
            "Invalid power type"
        );
        return (
            typeNames[powerType].firstNames,
            typeNames[powerType].lastNames
        );
    }
}
