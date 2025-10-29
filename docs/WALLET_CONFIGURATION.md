# Wallet Configuration Guide for Flora Network

## MetaMask Configuration

### Devnet Configuration (Current)
```
Network Name: Flora Devnet
RPC URL: http://52.9.17.25:8545
Chain ID: 766999 (0xBB417)
Currency Symbol: FLORA
Block Explorer: https://explorer.flora.network/flora-devnet
```

### Alternative RPC Endpoints
- http://52.9.17.25:8545 (Genesis)
- http://50.18.34.12:8545 (Guardian)
- http://204.236.162.240:8545 (Nexus)

## Currency Symbol Configuration

### Current Issue
The network uses `uflora` (micro-flora) as the base denomination, where:
- 1 FLORA = 1,000,000,000,000,000,000 uflora (18 decimals)
- The symbol should display as "FLORA" in wallets

### Fix for Denom Metadata (for next regenesis)
Add to genesis before starting chain:
```bash
GENESIS=~/.flora/config/genesis.json

# Add denom metadata for proper display
jq '.app_state.bank.denom_metadata = [{
  "description": "The native token of Flora",
  "denom_units": [
    {
      "denom": "uflora",
      "exponent": 0,
      "aliases": ["microflora"]
    },
    {
      "denom": "flora",
      "exponent": 18,
      "aliases": []
    }
  ],
  "base": "uflora",
  "display": "flora",
  "name": "Flora",
  "symbol": "FLORA"
}]' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"
```

## Keplr Wallet Configuration

```javascript
const chainConfig = {
  chainId: "flora_766999-1",
  chainName: "Flora Devnet",
  rpc: "http://52.9.17.25:26657",
  rest: "http://52.9.17.25:1317",
  bip44: {
    coinType: 60, // Ethereum coin type for Evmos chains
  },
  bech32Config: {
    bech32PrefixAccAddr: "flora",
    bech32PrefixAccPub: "florapub",
    bech32PrefixValAddr: "floravaloper",
    bech32PrefixValPub: "floravaloperpub",
    bech32PrefixConsAddr: "floravalcons",
    bech32PrefixConsPub: "floravalconspub"
  },
  currencies: [{
    coinDenom: "FLORA",
    coinMinimalDenom: "uflora",
    coinDecimals: 18,
    coinGeckoId: "flora"
  }],
  feeCurrencies: [{
    coinDenom: "FLORA",
    coinMinimalDenom: "uflora",
    coinDecimals: 18,
    coinGeckoId: "flora",
    gasPriceStep: {
      low: 10000000000,
      average: 25000000000,
      high: 40000000000
    }
  }],
  stakeCurrency: {
    coinDenom: "FLORA",
    coinMinimalDenom: "uflora",
    coinDecimals: 18,
    coinGeckoId: "flora"
  },
  features: ["ibc-transfer", "ibc-go", "eth-address-gen", "eth-key-sign"]
};

// Add to Keplr
await window.keplr.experimentalSuggestChain(chainConfig);
```

## Known Issues & Solutions

### Issue 1: Wrong Chain ID in MetaMask
**Symptom**: MetaMask shows chain ID 9000 instead of 766999
**Cause**: eth_chainId returns network ID instead of configured chain ID
**Solution**: Use manual configuration with Chain ID 766999

### Issue 2: Currency Symbol Shows as "ETH"
**Symptom**: MetaMask shows ETH instead of FLORA
**Solution**:
1. Add custom token in MetaMask
2. Or wait for proper token list integration

### Issue 3: Balance Not Showing
**Symptom**: Wallet connected but balance shows 0
**Possible Causes**:
- Wrong derivation path
- Account not funded
- RPC connection issue

**Check Balance via CLI**:
```bash
# Get EVM address from Cosmos address
florad debug addr flora1[address]

# Check balance
florad query bank balances flora1[address]
```

### Issue 4: Transactions Failing
**Common Causes**:
1. Gas price too low
2. Nonce issues
3. Chain ID mismatch

**Recommended Gas Settings**:
```
Gas Price: 25 Gwei (25000000000)
Gas Limit: 200000 (for simple transfers)
```

## Testing Wallet Connection

### 1. Test EVM RPC
```bash
# Get chain ID
curl -X POST http://52.9.17.25:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'

# Get latest block
curl -X POST http://52.9.17.25:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### 2. Test Account Balance
```bash
# Replace with your address
ADDRESS="0x..."
curl -X POST http://52.9.17.25:8545 \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"$ADDRESS\", \"latest\"],\"id\":1}"
```

## Faucet Accounts

### Available Test Accounts
- **Faucet**: flora1mgzls4ssrnw8ant466qurvydjrh907p9eyd9vm (10M FLORA)
- **Dev Pool**: flora1w42u8uarwzydzewz4u6j8z706crgj5jm78zwlw (1M FLORA)

### Getting Test Tokens
Currently manual - contact admin to send test tokens from faucet account.

Future: Automated faucet service at https://faucet.flora.network

## For Developers

### Web3.js Configuration
```javascript
const Web3 = require('web3');
const web3 = new Web3('http://52.9.17.25:8545');

// Check connection
web3.eth.getChainId().then(console.log); // Should show 766999
web3.eth.getBlockNumber().then(console.log); // Latest block
```

### Ethers.js Configuration
```javascript
const { ethers } = require('ethers');
const provider = new ethers.providers.JsonRpcProvider('http://52.9.17.25:8545');

// Custom network config
const network = {
  name: 'flora-devnet',
  chainId: 766999,
  _defaultProvider: (providers) => new providers.JsonRpcProvider('http://52.9.17.25:8545')
};
```

## Troubleshooting Checklist

- [ ] Is the RPC endpoint accessible? Test with curl
- [ ] Is the Chain ID correctly set to 766999?
- [ ] Is the currency symbol set to FLORA in wallet?
- [ ] Is the account funded with test tokens?
- [ ] Are gas settings appropriate for Flora?
- [ ] Is the explorer showing the correct network?

---

**Note**: After the next regenesis, we should add proper denom metadata to genesis for better wallet integration and symbol display.
