const truffleAssert = require("truffle-assertions");
var assert = require("assert");

const Monk = artifacts.require("Monk");
const Monkeys = artifacts.require("Monkeys");
const MonkeyGacha = artifacts.require("MonkeyGacha");

contract("Monkey Gacha", (accounts) => {
    let monkInstance;
    let monkeysInstance;
    let gachaInstance;

    const [owner, player1, player2] = accounts;

    // 1 ETH = 1000 MONK
    before(async () => {
        monkInstance = await Monk.deployed();
        monkeysInstance = await Monkeys.deployed();
        gachaInstance = await MonkeyGacha.deployed();
        await monkeysInstance.setGachaContract(gachaInstance.address);
    });

    describe("Starter Pack", () => {
        it("should draw starter pack, receive 3 monkeys", async () => {
            const ethAmount = web3.utils.toWei("5", "ether");

            await monkInstance.getMonks({from: player1, value: ethAmount});
            await monkInstance.giveMonkApproval(gachaInstance.address, 5000, {
                from: player1,
            });
            await gachaInstance.claimStarterPack({from: player1});

            const monkeyCount = await monkeysInstance.balanceOf(player1);
            assert.equal(monkeyCount.toString(), "3", "Player should receive 3 monkeys");
        });
    });

    describe("Single Draws", () => {
        it("should allow a player to draw a monkey", async () => {
            const ethAmount = web3.utils.toWei("1", "ether");

            await monkInstance.getMonks({from: player1, value: ethAmount});
            await monkInstance.giveMonkApproval(gachaInstance.address, 1000, {
                from: player1,
            });
            const drawMonkey = await gachaInstance.drawMonkey({from: player1});
            assert.notEqual(drawMonkey, undefined, "Monkey failed be drawn");
        });

        it("should fail if player doesn't have enough Monk tokens", async () => {
            await truffleAssert.fails(gachaInstance.drawMonkey({from: player2}));
        });
    });
});
