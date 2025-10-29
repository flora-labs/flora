# Flora Network RPC Endpoints

## Available Endpoints for Wallet Connections

### EVM RPC (MetaMask, Web3 Wallets)
Working endpoints on port 8545:
- Primary: `http://52.9.17.25:8545`
- Secondary: `http://50.18.34.12:8545`
- Tertiary: `http://204.236.162.240:8545`

**Chain Configuration:**
- Chain ID (Devnet): 766999 (0xBB417) - Active since October 16, 2025
- Chain ID (Mainnet): 766793 (0xBB349) - **Reserved for Production**
- Network Name: Flora Devnet
- Currency Symbol: FLORA
- Currency Decimals: 18
- Block Explorer: Not available yet

**Migration Notice**: Devnet chain ID migration completed on October 16, 2025. The active EVM chain ID is 766999 (0xBB417). Prior value 9000 (0x2328) is deprecated. See `docs/CHAIN_ID_STRATEGY.md` for background.

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
3. **Devnet**: Use eth_chainId=0xBB417 (766999)
4. **Mainnet (Future)**: Will use eth_chainId=0xBB349 (766793)

## Cosmos vs EVM Transfers
- EVM (0x… addresses): send via JSON‑RPC with chainId 766999.
- Cosmos (flora1… addresses): send via `florad tx bank send … --chain-id flora_766999-1`.

## MetaMask Configuration

### Legacy (Deprecated)
```javascript
const FLORA_CHAIN_CONFIG_CURRENT = {
  chainId: '0x2328',  // 9000 in decimal - DEPRECATED
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

### Devnet (Current)
```javascript
const FLORA_DEVNET_CONFIG = {
  chainId: '0xBB417',  // 766999 in decimal
  chainName: 'Flora Devnet',
  nativeCurrency: {
    name: 'FLORA',
    symbol: 'FLORA',
    decimals: 18
  },
  rpcUrls: ['http://52.9.17.25:8545'],  // Will update to https://rpc.devnet.flora.network
  blockExplorerUrls: []
};
```

### Mainnet (Reserved for Future)
```javascript
const FLORA_MAINNET_CONFIG = {
  chainId: '0xBB349',  // 766793 in decimal
  chainName: 'Flora Network',
  nativeCurrency: {
    name: 'FLORA',
    symbol: 'FLORA',
    decimals: 18
  },
  rpcUrls: ['https://rpc.flora.network'],
  blockExplorerUrls: ['https://explorer.flora.network']
};
```
