const Monk = artifacts.require("Monk");
const Monkeys = artifacts.require("Monkeys");
const MonkeyGacha = artifacts.require("MonkeyGacha");
const PlayerDetails = artifacts.require("PlayerDetails");
const Arena = artifacts.require("Arena");
const Bazaar = artifacts.require("Bazaar");
const fs = require('fs');
const path = require('path');

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

   // Load names from JSON file
   const namesPath = path.join(__dirname, '..', 'data', 'monkeyNames.json');
  
   // Add error handling
   try {
     const namesData = JSON.parse(fs.readFileSync(namesPath, 'utf8'));
     console.log('Successfully loaded names data');
 
     // Initialize names for each type
     console.log('Initializing Fire type names...');
     await gachaInstance.addNamesForType(
       0, // Fire
       namesData.fire.firstNames,
       namesData.fire.lastNames
     );
 
     console.log('Initializing Water type names...');
     await gachaInstance.addNamesForType(
       1, // Water
       namesData.water.firstNames,
       namesData.water.lastNames
     );
 
     console.log('Initializing Earth type names...');
     await gachaInstance.addNamesForType(
       2, // Grass
       namesData.grass.firstNames,
       namesData.grass.lastNames
     );
 
     console.log('Name initialization complete!');
   } catch (error) {
     console.error('Error loading or processing names:', error);
     console.error('Expected path:', namesPath);
     throw error;
   }
};