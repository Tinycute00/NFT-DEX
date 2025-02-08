import { expect } from "chai";
import pkg from "hardhat";
const { ethers } = pkg;

describe("MockFLP", function () {
  let mockFLP;
  let owner;

  beforeEach(async function () {
    [owner] = await ethers.getSigners();
    const MockFLP = await ethers.getContractFactory("MockFLP");
    mockFLP = await MockFLP.deploy();
    await mockFLP.deployed();
  });

  it("should initialize with zero total supply", async function () {
    const totalSupply = await mockFLP.totalSupply();
    expect(totalSupply.toNumber()).to.equal(0);
  });

  it("should mint FLP and update total supply", async function () {
    await mockFLP.mint(owner.address, 1, 0, 0, 0);
    const totalSupply = await mockFLP.totalSupply();
    expect(totalSupply.toNumber()).to.equal(1);
  });

  it("should burn FLP and update total supply", async function () {
    await mockFLP.mint(owner.address, 1, 0, 0, 0);
    await mockFLP.burn(owner.address, 1);
    const totalSupply = await mockFLP.totalSupply();
    expect(totalSupply.toNumber()).to.equal(0);
  });
}); 