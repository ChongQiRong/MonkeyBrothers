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

    // Stats ranges per rarity
    struct StatRange {
        uint256 minAttack;
        uint256 maxAttack;
        uint256 minHealth;
        uint256 maxHealth;
    }

    mapping(uint8 => StatRange) public rarityStats;

    string[] private firstNames;
    string[] private lastNames;

    event MonkeyDrawn(
        address indexed player,
        uint256 indexed tokenId,
        uint8 rarity,
        uint8 powerType,
        uint256 attack,
        uint256 health,
        string name
    );

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

        _initializeNames();
    }

    function drawMonkey() external {
        // Check if player has enough MONK tokens
        require(
            monkToken.balanceOf(msg.sender) >= 1 ether,
            "Insufficient MONK balance"
        );

        // Transfer MONK tokens from player
        require(
            monkToken.transferFrom(msg.sender, address(this), 1 ether),
            "Transfer failed"
        );

        // Generate random monkey attributes
        uint8 rarity = _determineRarity();
        uint8 powerType = uint8(_random(uint256(Monkeys.PowerType.Earth) + 1));
        string memory name = _generateName();

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

    function _generateName() internal view returns (string memory) {
        string memory firstName = firstNames[_random(firstNames.length)];
        string memory lastName = lastNames[_random(lastNames.length)];
        return string(abi.encodePacked(firstName, " ", lastName));
    }

    function _initializeNames() internal {
        firstNames = [
            "Sun",
            "Cloud",
            "Storm",
            "Thunder",
            "Lightning",
            "Rain",
            "Wind",
            "Star"
        ];
        lastNames = [
            "Warrior",
            "Guardian",
            "Protector",
            "Knight",
            "Champion",
            "Hero",
            "Legend"
        ];
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

    function addNames(
        string[] calldata _firstNames,
        string[] calldata _lastNames
    ) external onlyOwner {
        for (uint i = 0; i < _firstNames.length; i++) {
            firstNames.push(_firstNames[i]);
        }
        for (uint i = 0; i < _lastNames.length; i++) {
            lastNames.push(_lastNames[i]);
        }
    }
}
