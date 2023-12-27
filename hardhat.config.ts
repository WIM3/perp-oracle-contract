import "@nomiclabs/hardhat-ethers"
import "@nomiclabs/hardhat-waffle"
import "@typechain/hardhat"
import "hardhat-dependency-compiler"
import "hardhat-gas-reporter"
import { HardhatUserConfig } from "hardhat/config"
import "solidity-coverage"

const config: HardhatUserConfig = {
    solidity: {
        compilers: [
            {
                version: "0.7.6",
                settings: {
                    optimizer: { enabled: true, runs: 200 },
                    evmVersion: "berlin",
                    // for smock to mock contracts
                    outputSelection: {
                        "*": {
                            "*": ["storageLayout"],
                        },
                    },
                },
            },
            {
                version: "0.8.17",
                settings: {
                    // for smock to mock contracts
                    outputSelection: {
                        "*": {
                            "*": ["storageLayout"],
                        },
                    },
                },
            },
            {
                version: "0.8.20",
                settings: {
                    // for smock to mock contracts
                    outputSelection: {
                        "*": {
                            "*": ["storageLayout"],
                        },
                    },
                },
            },
            {
                version: "0.6.2",
                settings: {
                    // for smock to mock contracts
                    outputSelection: {
                        "*": {
                            "*": ["storageLayout"],
                        },
                    },
                },
            },
            {
                version: "0.8.12",
                settings: {
                    // for smock to mock contracts
                    outputSelection: {
                        "*": {
                            "*": ["storageLayout"],
                        },
                    },
                },
            }
        ]
        
    },
    mocha: {
        timeout: 100000,
    },
    
    networks: {
        hardhat: {
            allowUnlimitedContractSize: true,
        },
    },
    gasReporter: {
        enabled: true,
    },
}

export default config
