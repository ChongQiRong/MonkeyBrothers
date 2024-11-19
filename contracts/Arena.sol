// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./PlayerDetails.sol";
import "./Monkey.sol";
import "./Monk.sol";

/**
 * @title Fight
 * @dev Fight is the main functionality of our game, where an array of 5 Beasts fight with another 5 Beasts and
 * and the winner wins gems based on the difference in damage dealt to the opponent.
 */
contract Arena {
    Monkeys monkeyContract;
    Monk monkContract;
    PlayerDetails playerDetailsContract;
    address[] matchmakingQueue;
    address owner;

    /**
     * Sets the values for the owner of contract, gemContract, cardContract and mmrContract
     * @param _monkContract Address of deployed Monk contract
     * @param _monkeyContract Address of deployed Monkeys contract
     * @param _playerDetailsContract Address of deployed PlayerDetails contract
     */
    constructor(
        address _monkContract,
        address _monkeyContract,
        address _playerDetailsContract
    ) {
        owner = msg.sender;
        monkeyContract = Monkeys(_monkeyContract);
        monkContract = Monk(_monkContract);
        playerDetailsContract = PlayerDetails(_playerDetailsContract);
    }

    // owner => array of cards (for players in queue)
    mapping(address => uint256[]) internal _cardsOfPlayersInQueue;
    // owner => scale
    mapping(address => uint256) internal _scale;

    event inQueue(address player);
    event damageDifference(uint256 diff);
    event outcomeWin(address winner);
    event outcomeDraw();

    /**
     * @dev Places a user to the matchmaking queue if queue is empty, else battle with the person at the top of the queue
     * @param monkeys Array of 3 monkey token IDs in the order they will battle
     */
    function fight(
        uint256[] memory monkeys
    ) public isOwnerOfMonkeys(monkeys) isCorrectNumMonkeys(monkeys) {
        // If queue is empty, add player to queue
        if (matchmakingQueue.length == 0) {
            matchmakingQueue.push(msg.sender);
            _cardsOfPlayersInQueue[msg.sender] = monkeys;
            emit inQueue(msg.sender);
            return;
        }

        // Get opponent from front of queue
        address opponent = matchmakingQueue[0];
        uint256[] memory opponentMonkeys = _cardsOfPlayersInQueue[opponent];

        // Remove opponent from queue
        matchmakingQueue.pop();
        delete _cardsOfPlayersInQueue[opponent];

        // Calculate total damage for each player
        uint256 myDamage = 0;
        uint256 opponentDamage = 0;

        // Battle each monkey pair
        for (uint i = 0; i < monkeys.length; i++) {
            uint[] memory powerTypes = getPowerTypes(
                monkeys[i],
                opponentMonkeys[i]
            );

            Monkeys.Monkey memory myMonkey = monkeyContract.getMonkey(
                monkeys[i]
            );
            Monkeys.Monkey memory enemyMonkey = monkeyContract.getMonkey(
                opponentMonkeys[i]
            );

            myDamage += (myMonkey.attack * powerTypes[0]) / 10;
            opponentDamage += (enemyMonkey.attack * powerTypes[1]) / 10;
        }

        // Determine winner and award experience
        if (myDamage > opponentDamage) {
            emit outcomeWin(msg.sender);
            playerDetailsContract.addExperience(msg.sender, 100);
            emit damageDifference(myDamage - opponentDamage);
        } else if (opponentDamage > myDamage) {
            emit outcomeWin(opponent);
            playerDetailsContract.addExperience(opponent, 100);
            emit damageDifference(opponentDamage - myDamage);
        } else {
            emit outcomeDraw();
            // Award less exp for a draw
            playerDetailsContract.addExperience(msg.sender, 50);
            playerDetailsContract.addExperience(opponent, 50);
        }
    }

    /**
     * @dev Getter for the power type of 2 Monkeys
     * @param myMonkey ID of my Monkey
     * @param enemyMonkey ID of enemy Monkey
     */
    function getPowerTypes(
        uint256 myMonkey,
        uint256 enemyMonkey
    ) internal view returns (uint[] memory) {
        uint[] memory powerTypes = new uint[](2);
        powerTypes[0] = 10;
        powerTypes[1] = 10;

        Monkeys.Monkey memory my = monkeyContract.getMonkey(myMonkey);
        Monkeys.Monkey memory enemy = monkeyContract.getMonkey(enemyMonkey);

        // Implement elemental advantages based on PowerType
        if (isEffectiveAgainst(my.powerType, enemy.powerType)) {
            powerTypes[0] += 2;
            powerTypes[1] -= 2;
        } else if (isEffectiveAgainst(enemy.powerType, my.powerType)) {
            powerTypes[0] -= 2;
            powerTypes[1] += 2;
        }

        return powerTypes;
    }

    function isEffectiveAgainst(
        Monkeys.PowerType attacker,
        Monkeys.PowerType defender
    ) internal pure returns (bool) {
        if (
            attacker == Monkeys.PowerType.Fire &&
            defender == Monkeys.PowerType.Earth
        ) return true;
        if (
            attacker == Monkeys.PowerType.Water &&
            defender == Monkeys.PowerType.Fire
        ) return true;
        if (
            attacker == Monkeys.PowerType.Earth &&
            defender == Monkeys.PowerType.Water
        ) return true;
        return false;
    }

    /**
     * @dev Withdraw gem commissions from fight back to owner of contract
     */
    function withdraw() public {
        uint256 amt = monkContract.checkMonks();
        monkContract.transferMonks(owner, amt);
    }

    /**
     * @dev Modifier to check if all cards belong to player
     */
    modifier isOwnerOfMonkeys(uint256[] memory monkeys) {
        for (uint i = 0; i < monkeys.length; i++) {
            require(
                monkeyContract.ownerOf(monkeys[i]) == msg.sender,
                "Monkey does not belong to player"
            );
        }
        _;
    }

    /**
     * @dev Modifier to check if number of cards are correct in the array of card ids
     */
    modifier isCorrectNumMonkeys(uint256[] memory monkeys) {
        require(monkeys.length == 3, "Must use exactly 3 monkeys");
        _;
    }
}
