const _deploy_contracts = require("../migrations/2_deploy_contracts");
const truffleAssert = require("truffle-assertions"); 
const BigNumber = require("bignumber.js"); 
var assert = require("assert");
const { describe } = require("node:test");

const Monk = artifacts.require("Monk");
const Monkeys = artifacts.require("Monkeys");
const MonkeyGacha = artifacts.require("MonkeyGacha");
const PlayerDetails = artifacts.require("PlayerDetails");
const Arena = artifacts.require("Arena");
const Bazaar = artifacts.require("Bazaar");



contract("Monkey Brothers", accounts => {
    let monkInstance;
    let monkeysInstance;
    let gachaInstance;
    let playerDetailsInstance;
    let arenaInstance;
    let bazaarInstance;

    const [owner, player1, player2] = accounts;

    before(async () => {
        monkInstance = await Monk.deployed();
        monkeysInstance = await Monkeys.deployed();
        gachaInstance = await MonkeyGacha.deployed();
        playerDetailsInstance = await PlayerDetails.deployed();
        arenaInstance = await Arena.deployed();
        bazaarInstance = await Bazaar.deployed();

        await monkeysInstance.setGachaContract(gachaInstance.address);
        await playerDetailsInstance.setArenaContract(arenaInstance.address);
    });

    console.log("Testing Monkey Brothers contracts deployed successfully");

    describe("Monk Token", () => {

        it("Check initial MONK supply", async () => {
            const initialSupply = await monkInstance.currentMonkSupply.call();
            assert.equal(initialSupply.toString(), "0", "Initial supply should be 0");
          });
        
          it("Get MONK with ETH", async () => {
            const ethAmount = web3.utils.toWei("1", "ether");
            const expectedMonks = 1000; // 1 ETH = 1000 MONK
        
            await monkInstance.getMonks({from: accounts[1], value: ethAmount});
            const balance = await monkInstance.checkMonks.call({from: accounts[1]});
        
            assert.equal(balance.toString(), expectedMonks.toString());
          })
        
          it("Transfer MONK between accounts", async () => {
            const transferAmount = 100;
            
            await monkInstance.transferMonks(accounts[2], transferAmount, {from: accounts[1]});
            const recipientBalance = await monkInstance.checkMonksOf.call(accounts[2]);
        
            assert.equal(recipientBalance.toString(), transferAmount.toString());
          });
          
          it("Check MONK supply", async () => {
            const initialSupply = await monkInstance.currentMonkSupply.call();
            assert(initialSupply > 0, "Supply should be greater than 0");
          });
    });

    describe("Monkey Gacha", () => {
        it("should draw starter pack, receive 3 monkeys", async () => {
            const ethAmount = web3.utils.toWei("5", "ether");

            await monkInstance.getMonks({from: player1, value: ethAmount});
            await monkInstance.giveMonkApproval(gachaInstance.address, 5000, {from: player1});
            await gachaInstance.claimStarterPack({from: player1});

            const monkeyCount = await monkeysInstance.balanceOf(player1);
            assert.equal(monkeyCount.toString(), "3", "Player should receive 3 monkeys");
        });
        it("should allow a player to draw a monkey", async () => {
            const ethAmount = web3.utils.toWei("1", "ether");
        
            await monkInstance.getMonks({from: player1, value: ethAmount});
            await monkInstance.giveMonkApproval(gachaInstance.address, 1000, {from: player1});
            const drawMonkey = await gachaInstance.drawMonkey({from: player1});
            assert.notEqual(drawMonkey, undefined, "Monkey failed be drawn");
        });
        
        it("should fail if player doesn't have enough Monk tokens", async () => {
            await truffleAssert.fails(
                gachaInstance.drawMonkey({from: player2})
            );
        });
    });

    describe("Battle Arena", () => {
        it("should allow a player to battle another player", async () => {
            // Ensure player 2 has 3 monkeys
            await monkInstance.getMonks({from: player2, value: web3.utils.toWei("3", "ether")});
            await monkInstance.giveMonkApproval(gachaInstance.address, 3000, {from: player2});
            await gachaInstance.claimStarterPack({from: player2});

            // Player 1 places 3 monkeys in the arena
            const monkey1Id = 0;
            const monkey2Id = 1;
            const monkey3Id = 2;
            await arenaInstance.fight([monkey1Id, monkey2Id, monkey3Id], {from: player1});

            // Player 2 places 3 monkeys in the arena
            const monkey4Id = 4;    
            const monkey5Id = 5;
            const monkey6Id = 6;
            const result = await arenaInstance.fight([monkey4Id, monkey5Id, monkey6Id], {from: player2});
            try {
                truffleAssert.eventEmitted(result, "outcomeWin", (ev) => {
                    // Either player 1 or player 2 wins
                    return ev.winner === player1 || ev.winner === player2;
                });
            } catch {
                // Player 1 and player 2 draw
                truffleAssert.eventEmitted(result, "outcomeDraw");
            }
        });

        it("allow player to see their details after battle", async () => {
            const player1Level = await playerDetailsInstance.getPlayerLevel(player1);
            const player2Level = await playerDetailsInstance.getPlayerLevel(player2);
            assert(player1Level.toString() === "1" || player1Level.toString() === "2" || player2Level.toString() === "1" || player2Level.toString() === "2", "Player level should be either 1 or 2");
        });
    });


});