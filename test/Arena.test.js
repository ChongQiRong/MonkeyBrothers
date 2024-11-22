const truffleAssert = require("truffle-assertions");
var assert = require("assert");

const Monk = artifacts.require("Monk");
const Monkeys = artifacts.require("Monkeys");
const MonkeyGacha = artifacts.require("MonkeyGacha");
const PlayerDetails = artifacts.require("PlayerDetails");
const Arena = artifacts.require("Arena");

contract("Arena", (accounts) => {
    let monkInstance;
    let monkeysInstance;
    let gachaInstance;
    let playerDetailsInstance;
    let arenaInstance;

    const [player1, player2] = accounts;
    const ethAmount = web3.utils.toWei("1", "ether");
    const fiveEthAmount = web3.utils.toWei("5", "ether");
    let player1Monkeys = [];
    let player2Monkeys = [];

    before(async () => {
        monkInstance = await Monk.deployed();
        monkeysInstance = await Monkeys.deployed();
        gachaInstance = await MonkeyGacha.deployed();
        playerDetailsInstance = await PlayerDetails.deployed();
        arenaInstance = await Arena.deployed();

        await monkeysInstance.setGachaContract(gachaInstance.address);
        await playerDetailsInstance.setArenaContract(arenaInstance.address);

        await monkInstance.getMonks({from: player1, value: fiveEthAmount});
        await monkInstance.giveMonkApproval(gachaInstance.address, 5000, {
            from: player1,
        });
        const result1 = await gachaInstance.claimStarterPack({from: player1});
        player1Monkeys = result1.logs
            .filter((log) => log.event === "StarterPackClaimed")
            .flatMap((log) => log.args.monkeyIds);

        await monkInstance.getMonks({
            from: player2,
            value: fiveEthAmount,
        });
        await monkInstance.giveMonkApproval(gachaInstance.address, 5000, {
            from: player2,
        });
        const result2 = await gachaInstance.claimStarterPack({from: player2});
        player2Monkeys = result2.logs
            .filter((log) => log.event === "StarterPackClaimed")
            .flatMap((log) => log.args.monkeyIds);
    });

    describe("Battle Mechanics", () => {
        it("should allow a player to battle another player", async () => {
            // Check initial monk balance for player 1
            const player1MonkBalance = await monkInstance.checkMonksOf(player1);
            const player2MonkBalance = await monkInstance.checkMonksOf(player2);
            await monkInstance.getMonks({from: player1, value: ethAmount});
            await monkInstance.giveMonkApproval(arenaInstance.address, 1000, {
                from: player1,
            });
            await arenaInstance.fight(player1Monkeys, {
                from: player1,
            });
            await monkInstance.getMonks({from: player2, value: ethAmount});
            await monkInstance.giveMonkApproval(arenaInstance.address, 1000, {
                from: player2,
            });
            const result = await arenaInstance.fight(player2Monkeys, {from: player2});
            // Check final monk balance for player 1
            const player1FinalMonkBalance = await monkInstance.checkMonksOf(player1);
            // Check final monk balance for player 2
            const player2FinalMonkBalance = await monkInstance.checkMonksOf(player2);
            try {
                // Check that either player 1 or player 2 monk balance has increased
                assert(
                    player1FinalMonkBalance.toString() > player1MonkBalance.toString() ||
                        player2FinalMonkBalance.toString() > player2MonkBalance.toString(),
                    "Monk balance should have increased"
                );
                truffleAssert.eventEmitted(result, "outcomeWin", (ev) => {
                    // Either player 1 or player 2 wins
                    return ev.winner === player1 || ev.winner === player2;
                });
            } catch {
                // Player 1 and player 2 draw
                truffleAssert.eventEmitted(result, "outcomeDraw");
            }
        });
    });

    describe("Experience and Levels", () => {
        it("allow player to see their details after battle", async () => {
            const player1Level = await playerDetailsInstance.getPlayerLevel(player1);
            const player2Level = await playerDetailsInstance.getPlayerLevel(player2);
            assert(
                player1Level.toString() === "1" ||
                    player1Level.toString() === "2" ||
                    player2Level.toString() === "1" ||
                    player2Level.toString() === "2",
                "Player level should be either 1 or 2"
            );
        });
    });
});
