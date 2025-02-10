# Demo API Documentation

## 1. Overview
This document summarizes all the interfaces provided by the simulated backend (FakeContract) for front-end usage. These interfaces cover the functionalities of NFT minting, trading, staking, and interactions with FLP tokens (which are minted as ERC721 tokens when an NFT is staked). The front-end can use these APIs to enable actions like clicking on NFT images or other UI elements to trigger the respective operations.

**Note:** This document does not cover the creator-related contracts but only focuses on the NFT market, trading, staking, and related functionalities.

---

## 2. NFT-Related Interfaces

### 2.1 `mintNFT(rarity, imageUrl)`
- **Parameters:**
  - `rarity`: A numerical value representing the rarity of the NFT.
  - `imageUrl`: A string showing the URL for the NFT's image.
- **Functionality:**  
  Mints an NFT and assigns it to the current user. The minting process calculates the NFT's weight and base price based on its rarity.
- **Return Value:**  
  Returns an object: `{ tokenId, owner }`, where `tokenId` is the unique identifier for the new NFT and `owner` is the current user.

### 2.2 `getNFTs()`
- **Functionality:**  
  Returns the data of all NFTs.
- **Return Value:**  
  An object where keys are the NFT tokenIds. The details include:
  - `tokenId`, `rarity`, `weight`, `imageUrl`, `owner`, `basePrice`, `type`, `series`, etc.

### 2.3 `getListings()`
- **Functionality:**  
  Returns the current market listings for NFTs.
- **Return Value:**  
  An object where each key is a tokenId and the value is an object containing `{ price, seller }`.

### 2.4 `buyNFT(tokenId)`
- **Parameters:**
  - `tokenId`: The tokenId of the NFT to be purchased.
- **Functionality:**  
  Executes the buying process for an NFT. The front-end should call this interface to verify that the NFT exists and is listed. It also checks that the buyer (current user) has sufficient ETH balance. On success, the price is deducted from the buyer's ETH, and the NFT's ownership is transferred.
- **Return Value:**  
  On success, returns `{ tokenId, newOwner }`; otherwise, it returns `null`.

### 2.5 `sellNFT(tokenId)`
- **Parameters:**
  - `tokenId`: The tokenId of the NFT to be sold (listed).
- **Functionality:**  
  Sells the NFT to the system. The NFT is transferred to the system, and its price is calculated based on its internal `basePrice`. The sale price is then credited to the seller's account.
- **Return Value:**  
  On success, returns `{ tokenId, listingPrice }`.

### 2.6 `switchUser(user)`
- **Parameters:**
  - `user`: The username (e.g., `"Alice"` or `"Bob"`).
- **Functionality:**  
  Switches the current active user and updates the front-end interface accordingly (such as the user's wallet balance and the NFT list).

### 2.7 `initializeDemo()`
- **Functionality:**  
  Initializes the demo state by minting a set of NFTs for the default users (e.g., Alice and Bob) based on predefined data.
- **Return Value:**  
  None (this function directly updates the backend state).

### 2.8 `updateWalletDisplay()`
- **Functionality:**  
  Updates the wallet balance display on the page for the current user (by updating the DOM text accordingly).

---

## 3. FLP and NFT Staking-Related Interfaces

### 3.1 `interactFLP(action, amount)`
*(This interface was initially designed for the fungible FLP model. The current version mainly uses FLP tokens minted upon staking.)*
- **Parameters:**
  - `action`: A string, either `"earn"` (to earn FLP) or `"spend"` (to spend FLP).
  - `amount`: A number indicating the quantity.
- **Functionality:**  
  Adjusts the current user's FLP balance. (This is applicable for the older model; the new approach uses staked FLP tokens.)

### 3.2 `stakeNFT(tokenId)`
- **Parameters:**
  - `tokenId`: The tokenId of the NFT to stake.
- **Functionality:**  
  Carries out the NFT staking process:
  1. Validates that the `tokenId` is in the correct format, and that the NFT exists, is owned by the current user, and is not already staked.
  2. On successful validation, sets the NFT's `owner` to `"STAKE"`, effectively removing it from the user's available list.
  3. Records staking details in `stakeRecords` (including `tokenId`, `staker`, `stakeTime`, and `series`).
  4. Mints an associated FLP token (stored in `flpTokens`), where the FLP token's id (`flpTokenId`) is linked to the NFT's `tokenId`.
- **Return Value:**  
  On success, returns an object like:
  ```js
  {
    tokenId,
    msg: "Staking successful",
    details: { ...staking record... },
    flp: { ...FLP Token details... }
  }
  ```
  Otherwise, returns `null` with an error message.

### 3.3 `unstakeNFT(tokenId)`
- **Parameters:**
  - `tokenId`: The tokenId of the NFT to unstake.
- **Functionality:**  
  Unstakes an NFT:
  1. Validates that the `tokenId` has the correct format and that the NFT is currently staked by the current user.
  2. If valid, restores the NFT's `owner` back to the current user.
  3. Deletes the corresponding staking record (from `stakeRecords`) and the associated FLP token record (from `flpTokens`).
- **Return Value:**  
  On success, returns an object like `{ tokenId, msg: "Unstaking successful", details: { ...record details... } }`; otherwise returns `null`.

### 3.4 `getStakeRecords()`
- **Functionality:**  
  Returns all staking records for the current user.
- **Return Value:**  
  An array where each element includes details such as `tokenId`, `staker`, `stakeTime`, `series`, etc.

### 3.5 `getFLPToken(tokenId)`
- **Parameters:**
  - `tokenId`: The NFT tokenId associated with the FLP token.
- **Functionality:**  
  Looks up the FLP token details associated with the provided `tokenId`.
- **Return Value:**  
  Returns the FLP token details if it exists; otherwise, returns `null`.

### 3.6 `getUserFLPTokens(user)`
- **Parameters:**
  - `user`: The username.
- **Functionality:**  
  Returns a list of all FLP tokens owned by the specified user.
- **Return Value:**  
  An array where each element contains the details of one FLP token.

---

## 4. Auxiliary Interfaces

### 4.1 `simulateMarket()`
- **Functionality:**  
  Simulates a market transaction.
- **Return Value:**  
  Returns a string, for example, `"Market simulation completed."`, which is used to display the simulated result.

---

## 5. Usage Instructions
- **User Interaction:**  
  The front-end can use these interfaces to trigger operations (such as minting, listing, buying, selling, staking, and unstaking NFTs) by clicking on NFT images or other UI elements. All operations are based on the unique NFT `tokenId`.
  
- **Staking Display:**  
  Once an NFT is successfully staked, it is removed from the user's list and displayed in a dedicated staking section. The corresponding FLP token details are also shown, allowing for further interactions.

- **Interface Updates:**  
  When a user switches accounts or when a transaction occurs, functions like `switchUser()` and `updateWalletDisplay()` should be called to refresh the displayed information, ensuring the UI reflects the current state of the backend.

---

Front-end developers can use this API documentation to build a user-friendly interface that resembles a standard NFT marketplace, ensuring that every operation correctly triggers the intended backend logic and that the results are properly reflected on the screen. 