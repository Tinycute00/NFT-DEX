/*
  test/MarketSimulation.test.mjs
  Test market simulation based on user requirements: User-defined extra premium = (contract default premium * 2) (minimum 0.03 ETH), but user-defined price does not apply when selling to the system.
*/
import { expect } from "chai";
import pkg from "hardhat";
const { ethers } = pkg;

// Define ERC721 model scenario: three categories, each with different default premiums (in ETH)
const ERC721_SCENARIO = {
  categories: [
    { prob: 0.50, premium: 0.03 },
    { prob: 0.35, premium: 0.06 },
    { prob: 0.15, premium: 0.12 }
  ]
};

// Define ERC1155 model scenario: set different default premiums based on category proportions
const ERC1155_TOTAL = 10 + 50 + 250 + 250 + 450; // 1010
const ERC1155_SCENARIO = {
  categories: [
    { prob: 10 / ERC1155_TOTAL, premium: 0.15 },
    { prob: 50 / ERC1155_TOTAL, premium: 0.13 },
    { prob: 250 / ERC1155_TOTAL, premium: 0.11 },
    { prob: 250 / ERC1155_TOTAL, premium: 0.09 },
    { prob: 450 / ERC1155_TOTAL, premium: 0.07 }
  ]
};

// Simulate six market scenarios
const scenarios = [
  { stake: 0.50, systemInteraction: false, description: "Scenario 1: 50% staking, non-system market transaction" },
  { stake: 0.50, systemInteraction: true, delayed: true, description: "Scenario 2: 50% staking, system market transaction (delayed 10 days)" },
  { stake: 0.20, systemInteraction: false, description: "Scenario 3: 20% staking, non-system market transaction" },
  { stake: 0.20, systemInteraction: true, delayed: true, description: "Scenario 4: 20% staking, system market transaction (delayed 10 days)" },
  { stake: 0.00, systemInteraction: false, description: "Scenario 5: 0% staking, non-system market transaction" },
  { stake: 0.00, systemInteraction: true, delayed: true, description: "Scenario 6: 0% staking, system market transaction (delayed 10 days)" }
];

// Simulation parameters
const DAYS = 30;
const DAILY_TX = 200; // 200 transactions per day
const BASE_MINT_PRICE = 0.03; // Base price (ETH)
const FLP_FACTOR = 100; // FLP allocation per transaction = (user extra premium) * FLP_FACTOR

// Simulate a single ERC721 transaction, returning the default contract premium (ETH)
function simulateERC721Transaction() {
  const r = Math.random();
  let cumulative = 0;
  for (const cat of ERC721_SCENARIO.categories) {
    cumulative += cat.prob;
    if (r <= cumulative) return cat.premium;
  }
  return ERC721_SCENARIO.categories[0].premium;
}

// Simulate a single ERC1155 transaction, returning the default contract premium (ETH)
function simulateERC1155Transaction() {
  const r = Math.random();
  let cumulative = 0;
  for (const cat of ERC1155_SCENARIO.categories) {
    cumulative += cat.prob;
    if (r <= cumulative) return cat.premium;
  }
  return ERC1155_SCENARIO.categories[ERC1155_SCENARIO.categories.length - 1].premium;
}

// Simulate daily transactions
// For each transaction, if it meets the staking condition, perform calculations.
// If system market interaction is enabled and the transaction is a system market one (25% chance), skip calculation during delay days (first 10 days).
// For non-system market transactions: user extra premium = max(0.03, (contract default premium * 2))
function simulateDailyTransactions(day, stake, systemInteraction, delayed) {
  let dailyUserExtra = 0;
  let dailyFLP = 0;
  const erc721Tx = DAILY_TX / 2;
  const erc1155Tx = DAILY_TX / 2;
  
  // ERC721 transaction simulation
  for (let i = 0; i < erc721Tx; i++) {
    if (Math.random() <= stake) {
      const isSystem = systemInteraction && (Math.random() < 0.25);
      if (isSystem && delayed && day <= 10) continue; // Skip during delay period
      const contractPremium = simulateERC721Transaction();
      let userExtraPremium = 0;
      if (!isSystem) {
        userExtraPremium = Math.max(0.03, contractPremium * 2);
      }
      dailyUserExtra += userExtraPremium;
      dailyFLP += userExtraPremium * FLP_FACTOR;
    }
  }
  
  // ERC1155 transaction simulation
  for (let i = 0; i < erc1155Tx; i++) {
    if (Math.random() <= stake) {
      const isSystem = systemInteraction && (Math.random() < 0.25);
      if (isSystem && delayed && day <= 10) continue;
      const contractPremium = simulateERC1155Transaction();
      let userExtraPremium = 0;
      if (!isSystem) {
        userExtraPremium = Math.max(0.03, contractPremium * 2);
      }
      dailyUserExtra += userExtraPremium;
      dailyFLP += userExtraPremium * FLP_FACTOR;
    }
  }
  return { dailyUserExtra, dailyFLP };
}

// Simulate overall market behavior, returning cumulative data for each day
function simulateMarket(scenario) {
  let cumulativeExtra = 0;
  let cumulativeFLP = 0;
  const dailyData = [];
  for (let day = 1; day <= DAYS; day++) {
    const { dailyUserExtra, dailyFLP } = simulateDailyTransactions(day, scenario.stake, scenario.systemInteraction, scenario.delayed);
    cumulativeExtra += dailyUserExtra;
    cumulativeFLP += dailyFLP;
    dailyData.push({ day, dailyUserExtra, cumulativeExtra, dailyFLP, cumulativeFLP });
  }
  return dailyData;
}

// Test suite
describe("Market Simulation", function () {
  scenarios.forEach((scen, index) => {
    it(`should simulate ${scen.description}`, function () {
      const simulationData = simulateMarket(scen);
      const lastDay = simulationData[simulationData.length - 1];
      console.log(`\nScenario ${index + 1}: ${scen.description}`);
      console.log(`After ${DAYS} days: Cumulative User Extra Premium = ${lastDay.cumulativeExtra.toFixed(4)} ETH, Cumulative FLP Allocation = ${lastDay.cumulativeFLP.toFixed(2)}`);
      
      // When staking ratio is greater than 0, cumulative user extra premium and FLP allocation should be greater than 0
      if (scen.stake > 0) {
        expect(lastDay.cumulativeExtra).to.be.greaterThan(0);
        expect(lastDay.cumulativeFLP).to.be.greaterThan(0);
      }
    });
  });
}); 