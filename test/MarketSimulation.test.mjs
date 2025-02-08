/*
  test/MarketSimulation.test.mjs
  測試市場模擬，根據用戶需求: 用戶自訂額外溢價 = (合約預設溢價 * 2) (下限為 0.03 ETH)，但賣給系統時用戶自訂價格不成立
*/
import { expect } from "chai";
import pkg from "hardhat";
const { ethers } = pkg;

// 定義 ERC721 模型情境：三個類別，各自具有不同預設溢價 (單位 ETH)
const ERC721_SCENARIO = {
  categories: [
    { prob: 0.50, premium: 0.03 },
    { prob: 0.35, premium: 0.06 },
    { prob: 0.15, premium: 0.12 }
  ]
};

// 定義 ERC1155 模型情境：根據各類別比例，設置不同預設溢價
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

// 模擬六種市場情境
const scenarios = [
  { stake: 0.50, systemInteraction: false, description: "Scenario 1: 50% 質押, 非系統市場交易" },
  { stake: 0.50, systemInteraction: true, delayed: true, description: "Scenario 2: 50% 質押, 系統市場交易 (延時 10 天)" },
  { stake: 0.20, systemInteraction: false, description: "Scenario 3: 20% 質押, 非系統市場交易" },
  { stake: 0.20, systemInteraction: true, delayed: true, description: "Scenario 4: 20% 質押, 系統市場交易 (延時 10 天)" },
  { stake: 0.00, systemInteraction: false, description: "Scenario 5: 0% 質押, 非系統市場交易" },
  { stake: 0.00, systemInteraction: true, delayed: true, description: "Scenario 6: 0% 質押, 系統市場交易 (延時 10 天)" }
];

// 模擬參數設定
const DAYS = 30;
const DAILY_TX = 200; // 每天 200 筆交易
const BASE_MINT_PRICE = 0.03; // 基礎價格（ETH）
const FLP_FACTOR = 100; // 每筆交易的 FLP 分配 = (用戶額外溢價) * FLP_FACTOR

// 模擬 ERC721 單筆交易，返回預設合約溢價 (ETH)
function simulateERC721Transaction() {
  const r = Math.random();
  let cumulative = 0;
  for (const cat of ERC721_SCENARIO.categories) {
    cumulative += cat.prob;
    if (r <= cumulative) return cat.premium;
  }
  return ERC721_SCENARIO.categories[0].premium;
}

// 模擬 ERC1155 單筆交易，返回預設合約溢價 (ETH)
function simulateERC1155Transaction() {
  const r = Math.random();
  let cumulative = 0;
  for (const cat of ERC1155_SCENARIO.categories) {
    cumulative += cat.prob;
    if (r <= cumulative) return cat.premium;
  }
  return ERC1155_SCENARIO.categories[ERC1155_SCENARIO.categories.length - 1].premium;
}

// 模擬一天內交易情況
// 對每筆交易，若隨機符合質押條件，則進行計算。
// 若系統市場交互啟用且本筆交易屬於系統市場 (25% 機率)，在延時日 (前10天) 則跳過計算。
// 非系統市場交易時：用戶額外溢價 = max(0.03, (合約預設溢價 * 2))
function simulateDailyTransactions(day, stake, systemInteraction, delayed) {
  let dailyUserExtra = 0;
  let dailyFLP = 0;
  const erc721Tx = DAILY_TX / 2;
  const erc1155Tx = DAILY_TX / 2;
  
  // ERC721 交易模擬
  for (let i = 0; i < erc721Tx; i++) {
    if (Math.random() <= stake) {
      const isSystem = systemInteraction && (Math.random() < 0.25);
      if (isSystem && delayed && day <= 10) continue; // 延時期間略過
      const contractPremium = simulateERC721Transaction();
      let userExtraPremium = 0;
      if (!isSystem) {
        userExtraPremium = Math.max(0.03, contractPremium * 2);
      }
      dailyUserExtra += userExtraPremium;
      dailyFLP += userExtraPremium * FLP_FACTOR;
    }
  }
  
  // ERC1155 交易模擬
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

// 模擬整體市場行為，返回每天的累計數據
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

// 測試套件
describe("Market Simulation", function () {
  scenarios.forEach((scen, index) => {
    it(`should simulate ${scen.description}`, function () {
      const simulationData = simulateMarket(scen);
      const lastDay = simulationData[simulationData.length - 1];
      console.log(`\nScenario ${index + 1}: ${scen.description}`);
      console.log(`After ${DAYS} days: Cumulative User Extra Premium = ${lastDay.cumulativeExtra.toFixed(4)} ETH, Cumulative FLP Allocation = ${lastDay.cumulativeFLP.toFixed(2)}`);
      
      // 當質押比例大於 0 時，累計用戶自訂額外溢價與 FLP 分配應大於 0
      if (scen.stake > 0) {
        expect(lastDay.cumulativeExtra).to.be.greaterThan(0);
        expect(lastDay.cumulativeFLP).to.be.greaterThan(0);
      }
    });
  });
}); 