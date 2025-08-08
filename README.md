# Flora - EVM-Compatible Cosmos Blockchain

Flora is a high-performance, EVM-compatible blockchain built on the Cosmos SDK, designed to provide seamless interoperability between Ethereum and Cosmos ecosystems.

## 🌟 Key Features

- **Full EVM Compatibility**: Deploy Ethereum smart contracts without modification
- **Cosmos SDK Integration**: Access to the full Cosmos ecosystem and IBC protocol
- **Token Factory**: Create native tokens with custom logic
- **Cross-Chain Bridges**: Native ERC20 ↔ Cosmos token conversion
- **Advanced Precompiles**: Direct access to Cosmos modules from smart contracts
- **Interchain Accounts (ICA)**: Control accounts on other Cosmos chains
- **IBC Integration**: Full Inter-Blockchain Communication protocol support

## 🏗️ Architecture

Flora combines the best of both worlds:
- **Ethereum Virtual Machine (EVM)** for smart contract execution
- **Tendermint Consensus** for fast finality and Byzantine fault tolerance
- **Cosmos SDK** for modular blockchain architecture
- **IBC Protocol** for cross-chain communication

## 🚀 Quick Start

### Prerequisites
- Go 1.21+
- Make

### Build
```bash
make install
```

### Run Local Testnet
```bash
make testnet
```

## 📡 Network Endpoints

### Flora Testnet
- **Chain ID**: `flora_7668378-1`
- **EVM Chain ID**: `7668378`

#### Public RPC Endpoints
- **Validator 1**: `http://52.9.17.25:26657` (seed1.testnet.flora.network)
- **Validator 2**: `http://50.18.34.12:26657` (seed2.testnet.flora.network)
- **Validator 3**: `http://204.236.162.240:26657` (seed3.testnet.flora.network)

#### For Local Development
- **RPC**: `http://localhost:26657`
- **EVM RPC**: `http://localhost:8545`
- **REST API**: `http://localhost:1317`

#### Seed Nodes
```
seeds = "e3e06f1efeeca5daf7c7c0ad6a2216c0cadfa676@seed1.testnet.flora.network:26656,ebf668f4d1e2b21e895e7889050ebb43364c18b3@seed2.testnet.flora.network:26656,22a444539995192ada565f118069f11c0069e67e@seed3.testnet.flora.network:26656"
```

#### Explorer Configuration (Ping.pub)
Use any of these RPC endpoints in your Ping.pub configuration:
- Primary: `http://52.9.17.25:26657`
- Backup: `http://50.18.34.12:26657`
- Backup: `http://204.236.162.240:26657`

## 💰 Native Token

- **Symbol**: FLORA
- **Denomination**: uflora
- **Decimals**: 18
- **Type**: Native Cosmos SDK coin with EVM representation

## 🌐 Testnet Infrastructure

### Validator Nodes
1. **seed1.testnet.flora.network** (52.9.17.25)
   - AWS EC2 us-west-1, 16GB RAM, 145GB storage
   - Node ID: `e3e06f1efeeca5daf7c7c0ad6a2216c0cadfa676`

2. **seed2.testnet.flora.network** (50.18.34.12)
   - AWS EC2 us-west-1, 16GB RAM, 150GB storage
   - Node ID: `ebf668f4d1e2b21e895e7889050ebb43364c18b3`

3. **seed3.testnet.flora.network** (204.236.162.240)
   - AWS EC2 us-west-1, 16GB RAM, 150GB storage
   - Node ID: `22a444539995192ada565f118069f11c0069e67e`

### Network Configuration
- **Port 26656**: P2P (peer-to-peer communication)
- **Port 26657**: RPC (REST/JSON-RPC API)
- **Port 26660**: Prometheus metrics
- **Port 8545**: EVM JSON-RPC
- **Port 9090**: Cosmos gRPC

## 🔧 Developer Tools

### Smart Contract Deployment
```bash
# Using Hardhat/Foundry with standard Ethereum tools
# Network: http://localhost:8545
# Chain ID: 7668378
```

### Cosmos SDK Modules
Flora includes all standard Cosmos SDK modules plus:
- Bank, Staking, Governance, Distribution
- IBC Transfer, IBC Fee, Interchain Accounts
- Token Factory for custom token creation
- EVM module for Ethereum compatibility

### Precompiled Contracts
Direct access to Cosmos functionality from smart contracts:
- **Bank Precompile** (`0x0...1001`): Native token operations
- **Staking Precompile** (`0x0...1002`): Delegation and rewards
- **Distribution Precompile** (`0x0...1003`): Reward distribution
- **IBC Transfer Precompile** (`0x0...1004`): Cross-chain transfers

## 📚 Documentation

Comprehensive documentation is available in the `/docs` directory:
- [DevNet Guide](DEVNET.md)
- [Testing Guide](docs/TESTING_GUIDE.md)
- [Gas and Fees](docs/GAS_AND_FEES.md)
- [Genesis Configuration](docs/GENESIS_CONFIG.md)

## 🧪 Testing

### Unit Tests
```bash
make test
```

### Integration Tests
```bash
make ictest-basic
```

## 🤝 Contributing

We welcome contributions! Please see our contributing guidelines and:

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.

## 🔗 Links

- **Website**: https://flora.network
- **Explorer**: [Flora Explorer](https://explorer.flora.network) 
- **Discord**: [Community Discord](https://discord.flora.network)
- **Twitter**: [@FloraChain](https://twitter.com/FloraChain)

## ⚠️ Disclaimer

Flora is currently in active development. Use at your own risk in production environments.

---

Built with ❤️ using the Cosmos SDK and EVM ecosystem.
