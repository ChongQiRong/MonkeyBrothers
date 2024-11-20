const _deploy_contracts= require("../migrations/2_deploy_contracts");
const truffleAssert = require('truffle-assertions');
var assert = require('assert');

var Monk = artifacts.require("../contracts/Monk.sol");

contract("Monk", function(accounts) { 
  before(async () => {
    monkInstance = await Monk.deployed();
  });
  console.log("Testing Monk Contract");

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