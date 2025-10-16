# Flora Network RPC Endpoints

## Available Endpoints for Wallet Connections

### EVM RPC (MetaMask, Web3 Wallets)
Working endpoints on port 8545:
- Primary: `http://52.9.17.25:8545`
- Secondary: `http://50.18.34.12:8545`
- Tertiary: `http://204.236.162.240:8545`

**Chain Configuration:**
- Chain ID (Current): 9000 (0x2328) - **DEPRECATED** ⚠️ Conflicts with Evmos Testnet
- Chain ID (Devnet): 766999 (0xBB417) - **Approved for Regenesis**
- Chain ID (Mainnet): 766793 (0xBB349) - **Reserved for Production**
- Network Name: Flora Devnet
- Currency Symbol: FLORA
- Currency Decimals: 18
- Block Explorer: Not available yet

**Migration Notice**: Devnet chain ID will change from 9000 to 766999 during upcoming regenesis. Mainnet will use 766793. See `docs/CHAIN_ID_STRATEGY.md` and `docs/plans/todo/0001-runbook-evm-chainid-renumbering-regenesis.md` for details.

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
3. **Current**: Use eth_chainId=0x2328 (9000) for EVM signing until regenesis
4. **Post-Regenesis (Devnet)**: Use eth_chainId=0xBB417 (766999) - no more Evmos conflict warnings
5. **Mainnet (Future)**: Will use eth_chainId=0xBB349 (766793)

## Cosmos vs EVM Transfers
- EVM (0x… addresses): send via JSON‑RPC with chainId 9000.
- Cosmos (flora1… addresses): send via `florad tx bank send … --chain-id flora_7668378-1`.

## MetaMask Configuration

### Current (Pre-Regenesis)
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

### Post-Regenesis (Devnet)
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
