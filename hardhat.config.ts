import "@nomicfoundation/hardhat-ethers";
import "@openzeppelin/hardhat-upgrades";
import '@typechain/hardhat';
import { HardhatUserConfig } from 'hardhat/config';
import 'hardhat-deploy';
import "hardhat-gas-reporter";
import { config as dotenvConfig } from 'dotenv';
import { resolve } from 'path';
import "@nomicfoundation/hardhat-verify";

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || './.env';
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });

import "./tasks";

const config: HardhatUserConfig = {
    defaultNetwork: 'hardhat',
    solidity: {
        compilers: [
            {
                version: '0.8.20',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200
                    }
                }
            }
        ]
    },
    networks: {
        hardhat: {
            mining: {
                auto: true
            },
            loggingEnabled: false
        },
        bsc: {
            accounts: [process.env.PK],
            chainId: 56,
            url: 'https://bsc.rpc.blxrbdn.com'
        },
        bsctest: {
            accounts: [process.env.PK],
            chainId: 97,
            url: 'https://bsc-testnet-rpc.publicnode.com'
        },
    },

    typechain: {
        outDir: 'types/evm',
        target: 'ethers-v6'
    },

    sourcify: {
        enabled: true
    },
};

export default config;
