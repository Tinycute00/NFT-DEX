# Project Structure

This document outlines the overall organization of the project, including the directory structure and the purpose of each folder.

## Directory Structure

```
root/
├── contracts/  
│   ├── NFTDEXCore.sol  
│   ├── PoolSystem.sol  
│   ├── NFTAttributes.sol  
│   ├── NFTStaking.sol  
│   ├── CreatorNFT721Unlimited.sol  
│   └── … (other contract files)
│   
├── interfaces/  
│   ├── IFLPContract.sol  
│   ├── NFTDEXInterface.sol  
│   ├── INFTAttributes.sol  
│   └── … (other interface definitions)
│   
├── test/  
│   ├── NFTDEXCore.test.mjs  
│   ├── TestContracts.test.mjs  
│   ├── MarketSimulation.test.mjs  
│   └── … (other test files)
│   
├── demo/  
│   └── index.html  
│       (This demo is a non-blockchain version, using HTML/CSS/JS to simulate interaction processes for investor presentations.)
│   
├── docs/  
│   ├── DEXMechanism.md  
│   ├── TestPlan.md  
│   └── PROJECT_STRUCTURE.md  (This document, introducing the overall organization of the project)
│   
├── README.md  (General project introduction, usage, deployment instructions, etc.)
├── package.json  
├── hardhat.config.cjs  (or .js, depending on your project's configuration)
└── … (other configuration or support files)
```

## Purpose of Each Folder

- **contracts/**: Contains all the smart contract files that define the core logic and functionality of the NFT DEX, including market operations, staking, and attribute management.

- **interfaces/**: Contains interface definitions for the contracts, providing a clear contract for interaction and integration with other components.

- **test/**: Contains test files for verifying the functionality and correctness of the contracts. Tests are written using Hardhat and Chai.

- **demo/**: Contains a non-blockchain demo version of the project, using HTML/CSS/JS to simulate the interaction processes. This is intended for presentations to investors and stakeholders.

- **docs/**: Contains documentation files, including detailed design documents, test plans, and project structure descriptions.

- **README.md**: Provides a general introduction to the project, including usage instructions and deployment guidelines.

- **package.json**: Lists the project's dependencies and scripts for building, testing, and deploying the project.

- **hardhat.config.cjs**: Configuration file for Hardhat, specifying network settings, compiler options, and other project-specific configurations.

This structure is designed to separate concerns and make it easy to navigate and maintain the project. Each folder serves a specific purpose, ensuring that the project is organized and easy to understand for developers and stakeholders alike. 