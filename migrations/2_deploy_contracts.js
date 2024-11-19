const Monk = artifacts.require("Monk");
const Monkeys = artifacts.require("Monkeys");
const MonkeyGacha = artifacts.require("MonkeyGacha");
const PlayerDetails = artifacts.require("PlayerDetails");
const Arena = artifacts.require("Arena");
const Bazaar = artifacts.require("Bazaar");

module.exports = async (deployer, network, accounts) => {
  // Deploy Monk token first as it's needed by other contracts
  await deployer.deploy(Monk);
  const monkInstance = await Monk.deployed();

  // Deploy Monkeys NFT with temporary gacha address
  // Using zero address initially since MonkeyGacha needs Monkeys address first
  await deployer.deploy(Monkeys, "0x0000000000000000000000000000000000000000", "https://api.monkeybrothers.io/metadata/");
  const monkeysInstance = await Monkeys.deployed();

  // Now deploy MonkeyGacha with correct token addresses
  await deployer.deploy(MonkeyGacha, monkInstance.address, monkeysInstance.address);
  const gachaInstance = await MonkeyGacha.deployed();

  // Update Monkeys contract with correct gacha address
  await monkeysInstance.setGachaContract(gachaInstance.address);

  // Deploy PlayerDetails
  await deployer.deploy(PlayerDetails);
  const playerDetailsInstance = await PlayerDetails.deployed();

  // Deploy Arena with all required addresses
  await deployer.deploy(
    Arena,
    monkInstance.address,
    monkeysInstance.address,
    playerDetailsInstance.address
  );
  const arenaInstance = await Arena.deployed();

  // Set Arena address in PlayerDetails
  await playerDetailsInstance.setArenaContract(arenaInstance.address);

  // Deploy Bazaar
  await deployer.deploy(Bazaar, monkeysInstance.address, monkInstance.address);
};