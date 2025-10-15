# Flora Network RPC Endpoints

## Available Endpoints for Wallet Connections

### EVM RPC (MetaMask, Web3 Wallets)
Working endpoints on port 8545:
- Primary: `http://52.9.17.25:8545`
- Secondary: `http://50.18.34.12:8545`
- Tertiary: `http://204.236.162.240:8545`

**Chain Configuration:**
- Chain ID: 9000 (0x2328)
- Network Name: Flora Testnet
- Currency Symbol: FLORA
- Currency Decimals: 18
- Block Explorer: Not available yet

### Tendermint RPC (Query only)
- `http://52.9.17.25:26657`
- `http://50.18.34.12:26657`
- `http://204.236.162.240:26657`

### Currently Unavailable
- ❌ Cosmos REST API (port 1317)
- ❌ gRPC (port 9090)
- ❌ WebSocket (port 8546)

## Important Notes
1. These are HTTP endpoints - HTTPS proxy needed for production
2. AWS security groups may need adjustment for external access
3. Use eth_chainId=0x2328 (9000) for EVM signing. net_version is 7668378; do not use it for EIP-155.

## Cosmos vs EVM Transfers
- EVM (0x… addresses): send via JSON‑RPC with chainId 9000.
- Cosmos (flora1… addresses): send via `florad tx bank send … --chain-id flora_7668378-1`.

## MetaMask Configuration
```javascript
const FLORA_CHAIN_CONFIG = {
  chainId: '0x2328',  // 9000 in decimal
  chainName: 'Flora Testnet',
  nativeCurrency: {
    name: 'FLORA',
    symbol: 'FLORA',
    decimals: 18
  },
  rpcUrls: ['http://52.9.17.25:8545'],
  blockExplorerUrls: []
};
```
