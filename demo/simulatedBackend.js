// Define the global simulated backend object FakeContract
var FakeContract = {
  // Two default users, each with a name, FLP balance, and simulated ETH wallet balance
  users: {
    "Alice": { name: "Alice", flp: 0, eth: 1000 },
    "Bob": { name: "Bob", flp: 0, eth: 1000 }
  },
  // The current active user, default is Alice
  currentUser: "Alice",
  // NFT database keyed by tokenId
  NFTs: {},
  // Market listings for NFTs (tokenId => { price, seller })
  listings: {},
  // Counter; increments automatically each time an NFT is minted
  nextTokenId: 1,
  // Global variables: total rarity sum and base price pool (in ETH) for this NFT series
  totalRaritySum: 335,
  basePricePool: 10,

  // Added: staking records (tokenId => staking record)
  stakeRecords: {},

  // Added: storage area for FLP tokens (FLP is the ERC721 Token minted upon NFT staking, linked to the NFT tokenId)
  flpTokens: {},

  // Returns the specified FLP token information (based on tokenId)
  getFLPToken: function(tokenId) {
    tokenId = parseInt(tokenId);
    return this.flpTokens[tokenId] || null;
  },

  // Returns an array of all FLP tokens owned by the given user
  getUserFLPTokens: function(user) {
    var tokens = [];
    for (var tokenId in this.flpTokens) {
      if (this.flpTokens[tokenId].owner === user) {
        tokens.push(this.flpTokens[tokenId]);
      }
    }
    return tokens;
  },

  // Simulate a market transaction; returns a transaction result string
  simulateMarket: function() {
    return "Market simulation completed.";
  },

  /**
   * Simulate NFT minting.
   * Mints an NFT to the current user; the weight is calculated as rarity * 100.
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
   * Simulate NFT purchase.
   * Only works if the NFT is listed in the market (i.e. exists in listings).
   */
  buyNFT: function(tokenId) {
    var nft = this.NFTs[tokenId];
    var listing = this.listings[tokenId];
    if (!nft || !listing) return null;
    var buyer = this.currentUser;
    if (nft.owner === buyer) return null;
    var price = listing.price;
    // Check whether the buyer has enough ETH
    if (this.users[buyer].eth < price) {
      alert("Insufficient balance, unable to purchase NFT");
      return null;
    }
    // Deduct the ETH from the buyer's wallet
    this.users[buyer].eth -= price;
    // Transfer NFT ownership to the buyer
    nft.owner = buyer;
    delete this.listings[tokenId];
    this.updateWalletDisplay();
    return { tokenId: tokenId, newOwner: buyer };
  },

  /**
   * Simulate FLP interaction: earn or spend FLP.
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
   * Modified: Simulate NFT staking (new version).
   * Marks the NFT's owner as "STAKE" and mints a corresponding FLP token (FLP is of ERC721 type).
   */
  stakeNFT: function(tokenId) {
    tokenId = parseInt(tokenId);
    if (isNaN(tokenId)) {
      alert("tokenId format error, must be a number.");
      return null;
    }
    var nft = this.NFTs[tokenId];
    if (!nft) {
      alert("NFT does not exist.");
      return null;
    }
    if (nft.owner !== this.currentUser) {
      alert("You do not own this NFT, cannot stake it.");
      return null;
    }
    if (typeof this.stakeRecords[tokenId] !== "undefined") {
      alert("This NFT is already staked.");
      return null;
    }
    // Stake NFT: mark the owner as "STAKE"
    nft.owner = "STAKE";
    // Record staking details (instead of deducting fungible FLP, mint an FLP token)
    this.stakeRecords[tokenId] = {
      tokenId: tokenId,
      staker: this.currentUser,
      stakeTime: Date.now(),
      series: nft.series || "Default"
    };
    // Mint FLP token bound to the NFT tokenId
    this.flpTokens[tokenId] = {
      flpTokenId: tokenId,
      linkedNFT: tokenId,
      owner: this.currentUser,
      stakeTime: Date.now(),
      series: nft.series || "Default"
    };
    return { tokenId: tokenId, msg: "Staking successful", details: this.stakeRecords[tokenId], flp: this.flpTokens[tokenId] };
  },

  /**
   * Modified: Simulate NFT unstaking.
   * Returns NFT ownership to the current user and burns the corresponding FLP token.
   */
  unstakeNFT: function(tokenId) {
    tokenId = parseInt(tokenId);
    if (isNaN(tokenId)) {
      alert("tokenId format error, must be a number.");
      return null;
    }
    var nft = this.NFTs[tokenId];
    if (!nft) {
      alert("NFT does not exist.");
      return null;
    }
    if (!this.stakeRecords[tokenId] || this.stakeRecords[tokenId].staker !== this.currentUser) {
      alert("This NFT is not staked by you.");
      return null;
    }
    // Unstake NFT: return NFT ownership to the current user
    nft.owner = this.currentUser;
    var record = this.stakeRecords[tokenId];
    delete this.stakeRecords[tokenId];
    // Burn the corresponding FLP token (delete from flpTokens)
    delete this.flpTokens[tokenId];
    return { tokenId: tokenId, msg: "Unstaking successful", details: record };
  },

  /**
   * Returns an object containing all NFTs.
   */
  getNFTs: function() {
    return this.NFTs;
  },

  /**
   * Returns the current market listings.
   */
  getListings: function() {
    return this.listings;
  },

  /**
   * User sells an NFT to the system.
   * If the current user owns the NFT, it transfers the NFT to the system and lists it with a price based on its preset basePrice.
   * The sale amount is credited to the seller's account (simulated immediate payment).
   */
  sellNFT: function(tokenId) {
    var nft = this.NFTs[tokenId];
    if (!nft) return null;
    if (nft.owner !== this.currentUser) {
      return null;
    }
    // Calculate sale price using the NFT's preset basePrice
    var price = nft.basePrice;
    // Transfer NFT to the system
    nft.owner = "SYSTEM";
    this.listings[tokenId] = { price: price, seller: this.currentUser };
    // Credit the sale price to the seller's account (simulated immediate payment)
    this.users[this.currentUser].eth += price;
    // Update wallet display
    this.updateWalletDisplay();
    return { tokenId: tokenId, listingPrice: price };
  },

  /**
   * Switches the current active user.
   */
  switchUser: function(user) {
    if (this.users[user]) {
      this.currentUser = user;
      var display = document.getElementById("currentUserDisplay");
      if (display) {
        display.innerText = "Current User: " + user;
      }
      this.updateWalletDisplay();
    }
  },

  /**
   * Initialize the demo state by minting predefined NFTs for Alice and Bob.
   */
  initializeDemo: function() {
    // Default data: 10 NFTs (same series)
    var defaultNFTs = [
      { user: "Alice", rarity: 80, type: "Legendary" },
      { user: "Alice", rarity: 15, type: "Common" },
      { user: "Alice", rarity: 15, type: "Common" },
      { user: "Alice", rarity: 15, type: "Common" },
      { user: "Alice", rarity: 15, type: "Common" },
      { user: "Bob", rarity: 30, type: "Rare" },
      { user: "Bob", rarity: 30, type: "Rare" },
      { user: "Bob", rarity: 60, type: "Uncommon" },
      { user: "Bob", rarity: 60, type: "Uncommon" },
      { user: "Bob", rarity: 15, type: "Ordinary" }
    ];
    for (var i = 0; i < defaultNFTs.length; i++) {
      var entry = defaultNFTs[i];
      this.currentUser = entry.user; // Temporarily set user to simulate minting
      var tokenId = this.nextTokenId++;
      var weight = entry.rarity * 100;
      // Calculate basePrice: (rarity / total rarity sum) * basePricePool
      var basePrice = (entry.rarity / this.totalRaritySum) * this.basePricePool;
      basePrice = Math.round(basePrice * 1000) / 1000; // Keep 3 decimal places
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
    // After minting NFTs, switch back to Alice by default
    this.currentUser = "Alice";
  },

  /**
   * Added: Update the wallet balance display on the page for the current user.
   */
  updateWalletDisplay: function() {
    var walletDisplay = document.getElementById("walletDisplay");
    if (walletDisplay) {
      walletDisplay.innerText = "Wallet Balance: " + this.users[this.currentUser].eth + " ETH";
    }
  },

  // Added: Return staking records for the current user.
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

// When the page loads, set up the related UI controls
document.addEventListener("DOMContentLoaded", function() {
  var header = document.querySelector("header");

  // 1. Add a dropdown for user switching.
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

  // 2. Display the current user.
  var currentUserDisplay = document.createElement("span");
  currentUserDisplay.id = "currentUserDisplay";
  currentUserDisplay.style.marginLeft = "20px";
  currentUserDisplay.innerText = "Current User: " + FakeContract.currentUser;
  header.appendChild(currentUserDisplay);

  // 3. Initialize demo state, minting 3 NFTs for each user.
  FakeContract.initializeDemo();

  // 4. In the NFT minting and trading section, add a "Simulate Sell NFT" button.
  var nftProcess = document.getElementById("nft-process");
  if (nftProcess) {
    var sellBtn = document.createElement("button");
    sellBtn.id = "sell-btn";
    sellBtn.innerText = "Simulate Sell NFT";
    nftProcess.appendChild(sellBtn);

    sellBtn.addEventListener("click", function() {
      // Prompt the user to input the NFT tokenId to sell.
      var tokenId = prompt("Please enter the NFT tokenId to sell");
      if (tokenId) {
        var result = FakeContract.sellNFT(tokenId);
        if (result) {
          alert("NFT successfully sold to the system and listed, TokenId: " +
                tokenId + ", Listing Price: " + result.listingPrice);
          // Re-render the NFT market if the renderNFTs function is defined
          if (typeof renderNFTs === "function") {
            renderNFTs();
          }
        } else {
          alert("Sale failed, please check if the NFT tokenId exists and belongs to you.");
        }
      }
    });
  }
});