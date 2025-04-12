import "@nomicfoundation/hardhat-ethers";
import "@openzeppelin/hardhat-upgrades";
import '@typechain/hardhat';
import { HardhatUserConfig } from 'hardhat/config';
import 'hardhat-deploy';
import "hardhat-gas-reporter";
import { config as dotenvConfig } from 'dotenv';
import { resolve } from 'path';
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
        mainnet: {
            accounts: [process.env.PK],
            chainId: 1,
            url: 'https://rpc.ankr.com/eth'
        },
        polygon: {
            accounts: [process.env.PK],
            chainId: 137,
            url: 'https://polygon-rpc.com'
        },
        bsc: {
            accounts: [process.env.PK],
            chainId: 56,
            url: 'https://go.getblock.io/20fc6cc909a040f18c500b6dae99c09b'
        },
        avalanche: {
            accounts: [process.env.PK],
            chainId: 43114,
            url: 'https://api.avax.network/ext/bc/C/rpc'
        },
        mirai: {
            accounts: [process.env.PK],
            chainId: 2718,
            url: 'https://rpc1.miraichain.io'
        },
        bsctest: {
            accounts: [process.env.PK],
            chainId: 97,
            url: 'https://bsc-testnet-rpc.publicnode.com'
        },
        miraitest: {
            accounts: [process.env.PK],
            chainId: 2195,
            url: 'https://rpc1-testnet.miraichain.io'
        }
    },

    typechain: {
        outDir: 'types/evm',
        target: 'ethers-v6'
    }
};

export default config;
