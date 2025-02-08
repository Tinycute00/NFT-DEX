import { expect } from 'chai';
import pkg from 'hardhat';
const { ethers } = pkg;

// A minimal ERC721 contract for testing purposes
import { Contract } from 'ethers';

// Test for NFTStaking contract

describe('NFTStaking', function () {
  let nftContract;
  let poolSystem;
  let mockFLP;
  let nftStaking;
  let owner, addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();

    // Deploy a minimal ERC721 contract for testing
    const ERC721Test = await ethers.getContractFactory('ERC721');
    // Using OpenZeppelin's ERC721. We'll deploy it with a name and symbol.
    nftContract = await ERC721Test.deploy('TestNFT', 'TNFT');
    await nftContract.deployed();

    // Mint an NFT to addr1 for staking test
    // Since plain ERC721 from OpenZeppelin does not have mint function, we'll assume owner mints by calling _mint via a deployed contract that exposes mint (for testing, use a simple contract) 
    // For simplicity, we deploy a minimal contract with a public mint
    const ERC721Mint = await ethers.getContractFactory('ERC721Mint');
    const nftMint = await ERC721Mint.deploy('TestNFT', 'TNFT');
    await nftMint.deployed();
    // Mint token id 1 to addr1
    await nftMint.connect(owner).mint(addr1.address, 1);
    nftContract = nftMint; // use this contract for testing

    // Deploy PoolSystem contract
    const PoolSystem = await ethers.getContractFactory('PoolSystem');
    poolSystem = await PoolSystem.deploy();
    await poolSystem.deployed();

    // Deploy MockFLP contract
    const MockFLP = await ethers.getContractFactory('MockFLP');
    mockFLP = await MockFLP.deploy();
    await mockFLP.deployed();

    // Deploy NFTStaking contract with the addresses of nftContract, mockFLP, and poolSystem
    const NFTStaking = await ethers.getContractFactory('NFTStaking');
    nftStaking = await NFTStaking.deploy(nftContract.address, mockFLP.address, poolSystem.address);
    await nftStaking.deployed();
  });

  it('should stake NFT correctly and update staked tokens', async function () {
    // Before staking, addr1 should own token 1
    expect(await nftContract.ownerOf(1)).to.equal(addr1.address);

    // addr1 approves NFTStaking contract to transfer the NFT
    await nftContract.connect(addr1).approve(nftStaking.address, 1);

    // Instead of using .to.emit, manually check the event in receipt
    const tx = await nftStaking.connect(addr1).stakeNFT(1);
    const receipt = await tx.wait();
    const event = receipt.events.find(e => e.event === 'NFTStaked');
    expect(event).to.exist;

    // After staking, NFT should be owned by staking contract
    expect(await nftContract.ownerOf(1)).to.equal(nftStaking.address);

    // Check staked tokens for addr1
    const staked = await nftStaking.getStakedTokens(addr1.address);
    expect(staked.map(t => t.toNumber())).to.include(1);
  });

  it('should unstake NFT correctly and remove from staked tokens', async function () {
    // Prepare: addr1 stakes NFT token 1
    await nftContract.connect(addr1).approve(nftStaking.address, 1);
    await nftStaking.connect(addr1).stakeNFT(1);

    // Instead of using .to.emit, manually check the event in receipt
    const tx2 = await nftStaking.connect(addr1).unstakeNFT(1);
    const receipt2 = await tx2.wait();
    const event2 = receipt2.events.find(e => e.event === 'NFTUnstaked');
    expect(event2).to.exist;

    // After unstaking, NFT ownership should return to addr1
    expect(await nftContract.ownerOf(1)).to.equal(addr1.address);

    // Check staked tokens for addr1 is empty
    const stakedAfter = await nftStaking.getStakedTokens(addr1.address);
    expect(stakedAfter.length).to.equal(0);
  });
});

// Minimal ERC721 contract with public mint function for testing purposes
// This contract is only created for testing NFTStaking functionality

describe('ERC721Mint', function () {
  let nftMint, owner, addr1;
  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();
    const ERC721Mint = await ethers.getContractFactory('ERC721Mint');
    nftMint = await ERC721Mint.deploy('TestNFT', 'TNFT');
    await nftMint.deployed();
  });

  it('should mint NFT correctly', async function () {
    await nftMint.mint(addr1.address, 1);
    expect(await nftMint.ownerOf(1)).to.equal(addr1.address);
  });
}); 