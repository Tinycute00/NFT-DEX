// 定義模擬後端全局對象 FakeContract
var FakeContract = {
  // 預設兩個用戶，每個用戶內包含姓名、FLP 余額以及模擬的 ETH 錢包餘額
  users: {
    "Alice": { name: "Alice", flp: 0, eth: 1000 },
    "Bob": { name: "Bob", flp: 0, eth: 1000 }
  },
  // 當前操作的用戶，預設為 Alice
  currentUser: "Alice",
  // NFT 資料庫，用 tokenId 做鍵值
  NFTs: {},
  // 市場上架的 NFT 記錄 (tokenId => { price, seller })
  listings: {},
  // 計數器，每次鑄 NFT 時自動遞增 tokenId
  nextTokenId: 1,
  // 新增全局變量：該系列 NFT 的總稀有度與底價池（單位 ETH）
  totalRaritySum: 335,
  basePricePool: 10,

  // 新增：質押記錄 (tokenId => 質押記錄)
  stakeRecords: {},

  // 新增：FLP tokens 存放領域（FLP 為質押 NFT 後鑄造出的 ERC721 Token，tokenId 與 NFT tokenId 相關聯）
  flpTokens: {},

  // 新增：返回指定 FLP token 的資訊（根據 tokenId）
  getFLPToken: function(tokenId) {
    tokenId = parseInt(tokenId);
    return this.flpTokens[tokenId] || null;
  },

  // 新增：返回指定用戶所有 FLP token 的陣列
  getUserFLPTokens: function(user) {
    var tokens = [];
    for (var tokenId in this.flpTokens) {
      if (this.flpTokens[tokenId].owner === user) {
        tokens.push(this.flpTokens[tokenId]);
      }
    }
    return tokens;
  },

  // 模擬市場交易，這裡僅返回一個交易結果字串
  simulateMarket: function() {
    return "市場交易模擬完成。";
  },

  /**
   * 模擬鑄造 NFT
   * 將 NFT 鑄造給當前用戶，計算權重 = rarity * 100
   */
  mintNFT: function(rarity, imageUrl) {
    var tokenId = this.nextTokenId++;
    var weight = rarity * 100;
    var nft = {
      tokenId: tokenId,
      rarity: rarity,
      weight: weight,
      imageUrl: imageUrl,
      owner: this.currentUser
    };
    this.NFTs[tokenId] = nft;
    return { tokenId: tokenId, owner: this.currentUser };
  },

  /**
   * 模擬購買 NFT
   * 僅針對市場上架（即 listings 中存在）的 NFT 進行購買
   */
  buyNFT: function(tokenId) {
    var nft = this.NFTs[tokenId];
    var listing = this.listings[tokenId];
    if (!nft || !listing) return null;
    var buyer = this.currentUser;
    if (nft.owner === buyer) return null;
    var price = listing.price;
    // 檢查買家 ETH 餘額是否充足
    if (this.users[buyer].eth < price) {
      alert("餘額不足，無法購買該 NFT");
      return null;
    }
    // 扣減買家錢包餘額
    this.users[buyer].eth -= price;
    // 將 NFT 轉讓給買家
    nft.owner = buyer;
    delete this.listings[tokenId];
    this.updateWalletDisplay();
    return { tokenId: tokenId, newOwner: buyer };
  },

  /**
   * 模擬 FLP 交互：賺取或花費 FLP
   */
  interactFLP: function(action, amount) {
    if (action === "earn") {
      this.users[this.currentUser].flp += amount;
    } else if (action === "spend") {
      if (this.users[this.currentUser].flp >= amount) {
        this.users[this.currentUser].flp -= amount;
      }
    }
    return this.users[this.currentUser].flp;
  },

  /**
   * 修改：模擬質押 NFT （新版）
   * 將 NFT 的所有權標記為 "STAKE"，並鑄造出對應的 FLP Token（FLP 為 ERC721 類型）
   */
  stakeNFT: function(tokenId) {
    tokenId = parseInt(tokenId);
    if (isNaN(tokenId)) {
      alert("tokenId 輸入格式錯誤，必須為數字。");
      return null;
    }
    var nft = this.NFTs[tokenId];
    if (!nft) {
      alert("該 NFT 不存在。");
      return null;
    }
    if (nft.owner !== this.currentUser) {
      alert("您不擁有該 NFT，無法質押。");
      return null;
    }
    if (typeof this.stakeRecords[tokenId] !== "undefined") {
      alert("該 NFT 已處於質押狀態。");
      return null;
    }
    // 質押 NFT：將所有權標記為 "STAKE"
    nft.owner = "STAKE";
    // 記錄質押詳情（不再扣減 fungible FLP，而是鑄造 FLP token）
    this.stakeRecords[tokenId] = {
      tokenId: tokenId,
      staker: this.currentUser,
      stakeTime: Date.now(),
      series: nft.series || "Default"
    };
    // 鑄造 FLP Token，與 NFT tokenId 綁定
    this.flpTokens[tokenId] = {
      flpTokenId: tokenId,
      linkedNFT: tokenId,
      owner: this.currentUser,
      stakeTime: Date.now(),
      series: nft.series || "Default"
    };
    return { tokenId: tokenId, msg: "質押成功", details: this.stakeRecords[tokenId], flp: this.flpTokens[tokenId] };
  },

  /**
   * 修改：模擬解除質押 NFT
   * 將 NFT 所有權返回給當前用戶，並銷毀對應的 FLP Token
   */
  unstakeNFT: function(tokenId) {
    tokenId = parseInt(tokenId);
    if (isNaN(tokenId)) {
      alert("tokenId 輸入格式錯誤，必須為數字。");
      return null;
    }
    var nft = this.NFTs[tokenId];
    if (!nft) {
      alert("該 NFT 不存在。");
      return null;
    }
    if (!this.stakeRecords[tokenId] || this.stakeRecords[tokenId].staker !== this.currentUser) {
      alert("該 NFT 不處於您的質押狀態。");
      return null;
    }
    // 解除質押後還原 NFT 擁有者為當前用戶
    nft.owner = this.currentUser;
    var record = this.stakeRecords[tokenId];
    delete this.stakeRecords[tokenId];
    // 銷毀對應的 FLP Token，即刪除 flpTokens 中的該條記錄
    delete this.flpTokens[tokenId];
    return { tokenId: tokenId, msg: "解除質押成功", details: record };
  },

  /**
   * 返回所有 NFT 的對象
   */
  getNFTs: function() {
    return this.NFTs;
  },

  /**
   * 返回市場上架資訊
   */
  getListings: function() {
    return this.listings;
  },

  /**
   * 用戶賣出 NFT 給系統
   * 如果當前用戶擁有該 NFT，則將 NFT 轉給系統，
   * 並按照規則（定價 = rarity * 10）進行上架
   */
  sellNFT: function(tokenId) {
    var nft = this.NFTs[tokenId];
    if (!nft) return null;
    if (nft.owner !== this.currentUser) {
      return null;
    }
    // 計算賣出價格，使用 NFT 事先計算好的 basePrice
    var price = nft.basePrice;
    // 將 NFT 轉移給系統
    nft.owner = "SYSTEM";
    this.listings[tokenId] = { price: price, seller: this.currentUser };
    // 將賣出價格入賬給賣家（模擬賣給系統後立即收款）
    this.users[this.currentUser].eth += price;
    // 更新錢包顯示
    this.updateWalletDisplay();
    return { tokenId: tokenId, listingPrice: price };
  },

  /**
   * 切換當前操作用戶
   */
  switchUser: function(user) {
    if (this.users[user]) {
      this.currentUser = user;
      var display = document.getElementById("currentUserDisplay");
      if (display) {
        display.innerText = "當前用戶: " + user;
      }
      this.updateWalletDisplay();
    }
  },

  /**
   * 初始化 demo 狀態：根據要求，為 Alice 與 Bob 分別鑄造特定 NFT 分佈
   */
  initializeDemo: function() {
    // 預設資料，共10個 NFT（同一系列）
    var defaultNFTs = [
      { user: "Alice", rarity: 80, type: "傳說" },
      { user: "Alice", rarity: 15, type: "一般" },
      { user: "Alice", rarity: 15, type: "一般" },
      { user: "Alice", rarity: 15, type: "一般" },
      { user: "Alice", rarity: 15, type: "一般" },
      { user: "Bob", rarity: 30, type: "稀有" },
      { user: "Bob", rarity: 30, type: "稀有" },
      { user: "Bob", rarity: 60, type: "罕見" },
      { user: "Bob", rarity: 60, type: "罕見" },
      { user: "Bob", rarity: 15, type: "普通" }
    ];
    for (var i = 0; i < defaultNFTs.length; i++) {
      var entry = defaultNFTs[i];
      this.currentUser = entry.user; // 暫時設置用戶以模擬鑄造
      var tokenId = this.nextTokenId++;
      var weight = entry.rarity * 100;
      // 按比例計算 basePrice = (rarity / total稀有度) * 底價池
      var basePrice = (entry.rarity / this.totalRaritySum) * this.basePricePool;
      basePrice = Math.round(basePrice * 1000) / 1000; // 保留3位小數
      this.NFTs[tokenId] = {
        tokenId: tokenId,
        rarity: entry.rarity,
        weight: weight,
        imageUrl: "https://via.placeholder.com/150?text=NFT+" + tokenId,
        owner: entry.user,
        basePrice: basePrice,
        type: entry.type,
        series: "Default"
      };
    }
    // 鑄完 NFT 後，預設切回 Alice
    this.currentUser = "Alice";
  },

  /**
   * 新增：更新頁面上錢包餘額顯示
   */
  updateWalletDisplay: function() {
    var walletDisplay = document.getElementById("walletDisplay");
    if (walletDisplay) {
      walletDisplay.innerText = "錢包餘額: " + this.users[this.currentUser].eth + " ETH";
    }
  },

  // 新增：返回當前用戶的質押記錄
  getStakeRecords: function() {
    var records = [];
    for (var tokenId in this.stakeRecords) {
      if (this.stakeRecords[tokenId].staker === this.currentUser) {
        records.push(this.stakeRecords[tokenId]);
      }
    }
    return records;
  },
};

// 頁面載入完成後設置相關 UI 控件
document.addEventListener("DOMContentLoaded", function() {
  var header = document.querySelector("header");

  // 1. 新增用戶切換下拉選單
  var userSelect = document.createElement("select");
  userSelect.id = "userSelect";
  var users = Object.keys(FakeContract.users);
  for (var i = 0; i < users.length; i++) {
    var option = document.createElement("option");
    option.value = users[i];
    option.text = users[i];
    userSelect.appendChild(option);
  }
  userSelect.addEventListener("change", function() {
    FakeContract.switchUser(this.value);
  });
  header.appendChild(userSelect);

  // 2. 顯示當前用戶
  var currentUserDisplay = document.createElement("span");
  currentUserDisplay.id = "currentUserDisplay";
  currentUserDisplay.style.marginLeft = "20px";
  currentUserDisplay.innerText = "當前用戶: " + FakeContract.currentUser;
  header.appendChild(currentUserDisplay);

  // 3. 初始化 demo 狀態，為每個用戶鑄 3 個 NFT
  FakeContract.initializeDemo();

  // 4. 在 NFT 鑄造與交易流程區塊額外新增「模擬賣出 NFT」按鈕
  var nftProcess = document.getElementById("nft-process");
  if (nftProcess) {
    var sellBtn = document.createElement("button");
    sellBtn.id = "sell-btn";
    sellBtn.innerText = "模擬賣出 NFT";
    nftProcess.appendChild(sellBtn);

    sellBtn.addEventListener("click", function() {
      // 提示用戶輸入欲賣出的 NFT tokenId
      var tokenId = prompt("請輸入欲賣出的 NFT tokenId");
      if (tokenId) {
        var result = FakeContract.sellNFT(tokenId);
        if (result) {
          alert("NFT 已成功賣給系統並上架，TokenId: " +
                tokenId + ", 定價: " + result.listingPrice);
          // 重新渲染 NFT 市場
          if (typeof renderNFTs === "function") {
            renderNFTs();
          }
        } else {
          alert("賣出失敗，請確認 NFT tokenId 是否存在且屬於您。");
        }
      }
    });
  }
});