# EVM RPC Troubleshooting Guide

**Status**: Reference Documentation  
**Created**: 2025-10-15  
**Last Updated**: 2025-10-15

## Table of Contents

- [Chain ID vs Network ID](#chain-id-vs-network-id)
- [Common Issues](#common-issues)
- [Wallet Configuration](#wallet-configuration)
- [Testing and Verification](#testing-and-verification)
- [Genesis Configuration](#genesis-configuration)

## Chain ID vs Network ID

### The Dual ID System

Flora (like all Cosmos EVM chains such as Evmos, Canto) uses **two different IDs**:

| Method | Returns | Purpose | Used For |
|--------|---------|---------|----------|
| `eth_chainId` | EVM Chain ID | EIP-155 transaction signing | **Transaction signing, wallets** |
| `net_version` | Network ID | Tendermint network identifier | **Cosmos network info only** |

### Current Configuration

**Live Devnet (Pre-Regenesis)**:
```bash
# eth_chainId (EVM)
curl -s -X POST http://52.9.17.25:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  | jq '.result'
# Returns: "0x2328" (9000 decimal)

# net_version (Tendermint/Cosmos)
curl -s -X POST http://52.9.17.25:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' \
  | jq '.result'
# Returns: "7668378" (decimal string)
```

**Post-Regenesis (Approved)**:
```bash
# eth_chainId (EVM) - CHANGES
curl -s -X POST http://52.9.17.25:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  | jq '.result'
# Will return: "0xBB417" (766999 decimal)

# net_version (Tendermint/Cosmos) - UNCHANGED
curl -s -X POST http://52.9.17.25:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' \
  | jq '.result'
# Will still return: "7668378" (decimal string)
```

### Why the Mismatch?

The Cosmos chain ID format is: `flora_7668378-1`
- `flora` = chain identifier
- `7668378` = network ID (embedded in Cosmos chain ID)
- `-1` = version/revision

The EVM chain ID is **separate** and configurable in genesis. This allows Cosmos EVM chains to:
1. Maintain compatibility with Cosmos ecosystem (using Cosmos chain ID)
2. Support EVM wallets/tools (using EVM chain ID)

## Common Issues

### Issue 1: MetaMask "Network ID Mismatch" Warning

**Symptom**:
```
⚠️ The network ID does not match the expected chain ID
Network ID: 7668378
Chain ID: 9000
```

**Cause**: MetaMask queries both `eth_chainId` and `net_version` and expects them to match (which they don't on Cosmos EVM chains).

**Solution**: **This is expected behavior** on Cosmos EVM chains. Ignore the warning, or:

1. **Always use `eth_chainId` for configuration**:
```javascript
const network = {
  chainId: '0x2328', // eth_chainId value
  // DO NOT set networkId - let MetaMask handle it
};
```

2. **For library configuration**:
```javascript
// ethers.js
const provider = new ethers.providers.JsonRpcProvider({
  url: 'http://52.9.17.25:8545',
  chainId: 9000 // Use eth_chainId value
});

// web3.js
const web3 = new Web3(new Web3.providers.HttpProvider(
  'http://52.9.17.25:8545'
));
// web3 will auto-detect chainId via eth_chainId
```

### Issue 2: Transaction Signing Failures

**Symptom**:
```
Error: Incorrect chainId
```

**Cause**: Application is using `net_version` instead of `eth_chainId` for EIP-155 signing.

**Solution**: Always use `eth_chainId` for transaction signing:

```javascript
// WRONG ❌
const networkId = await web3.eth.net.getId(); // Returns 7668378
const tx = {
  chainId: networkId, // WRONG!
  // ...
};

// CORRECT ✅
const chainId = await web3.eth.getChainId(); // Returns 9000
const tx = {
  chainId: chainId, // CORRECT!
  // ...
};
```

### Issue 3: Hardhat/Foundry Configuration

**Symptom**:
```
Error: network with chainId "7668378" not found
```

**Cause**: Tool configured with `net_version` instead of `eth_chainId`.

**Solution**:

**Hardhat (hardhat.config.js)**:
```javascript
module.exports = {
  networks: {
    flora: {
      url: "http://52.9.17.25:8545",
  chainId: 9000, // Use eth_chainId (current)
  // chainId: 766999, // Use this after regenesis (0xBB417)
      accounts: [process.env.PRIVATE_KEY]
    }
  }
};
```

**Foundry (foundry.toml)**:
```toml
[rpc_endpoints]
flora = "http://52.9.17.25:8545"

[etherscan]
flora = { key = "no-api-key-needed", chain = 9000 } # Use eth_chainId
```

**Cast/Forge commands**:
```bash
# Specify chain ID explicitly
cast send $CONTRACT "method()" \
  --rpc-url http://52.9.17.25:8545 \
  --chain-id 9000 \
  --private-key $PK
```

### Issue 4: EIP-155 Replay Protection Errors

**Symptom**:
```
Error: transaction doesn't have the correct nonce/chain id
```

**Cause**: Transaction signed with wrong chain ID.

**Solution**: Ensure EIP-155 signing uses `eth_chainId`:

```javascript
// ethers.js v6
const tx = await wallet.sendTransaction({
  to: recipient,
  value: amount,
  chainId: 9000, // Explicit eth_chainId
});

// ethers.js v5
const tx = {
  to: recipient,
  value: amount,
  chainId: 9000, // Must match eth_chainId
  nonce: await wallet.getTransactionCount(),
  gasLimit: 21000,
  gasPrice: await provider.getGasPrice(),
};
const signedTx = await wallet.signTransaction(tx);
```

## Wallet Configuration

### MetaMask - Manual Add

```javascript
// Current (Pre-Regenesis)
await window.ethereum.request({
  method: 'wallet_addEthereumChain',
  params: [{
    chainId: '0x2328', // 9000 - Use eth_chainId!
    chainName: 'Flora Devnet',
    nativeCurrency: {
      name: 'FLORA',
      symbol: 'FLORA',
      decimals: 18
    },
    rpcUrls: ['http://52.9.17.25:8545'],
    blockExplorerUrls: []
  }]
});

// Post-Regenesis
await window.ethereum.request({
  method: 'wallet_addEthereumChain',
  params: [{
    chainId: '0xBB417', // 766999 - Use eth_chainId!
    chainName: 'Flora Devnet',
    nativeCurrency: {
      name: 'FLORA',
      symbol: 'FLORA',
      decimals: 18
    },
    rpcUrls: ['https://rpc.devnet.flora.network'],
    blockExplorerUrls: ['https://explorer.devnet.flora.network']
  }]
});
```

### Rabby Wallet

Rabby automatically detects chain ID via `eth_chainId`. No special configuration needed.

### WalletConnect

```javascript
const provider = new WalletConnectProvider({
  rpc: {
    9000: 'http://52.9.17.25:8545', // Use eth_chainId as key
    // 766999: 'https://rpc.devnet.flora.network', // Post-regenesis (0xBB417)
  },
  chainId: 9000, // Current eth_chainId
});
```

## Testing and Verification

### Verify Chain IDs

```bash
#!/bin/bash
# check_chain_ids.sh

RPC="http://52.9.17.25:8545"

echo "Checking Flora EVM RPC Chain IDs..."
echo "===================================="

# Get eth_chainId (EVM chain ID)
echo -n "eth_chainId (EVM):     "
ETH_CHAIN_ID=$(curl -s -X POST $RPC \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  | jq -r '.result')
echo "$ETH_CHAIN_ID (decimal: $((ETH_CHAIN_ID)))"

# Get net_version (Network ID)
echo -n "net_version (Network): "
NET_VERSION=$(curl -s -X POST $RPC \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' \
  | jq -r '.result')
echo "$NET_VERSION"

echo ""
echo "Expected values:"
echo "  Pre-regenesis:  eth_chainId=0x2328 (9000), net_version=7668378"
echo "  Post-regenesis: eth_chainId=0xBB417 (766999), net_version=7668378"
```

### Test Transaction Signing

```javascript
// test_signing.js
const { ethers } = require('ethers');

async function testSigning() {
  const provider = new ethers.providers.JsonRpcProvider({
    url: 'http://52.9.17.25:8545',
    chainId: 9000 // Use eth_chainId
  });
  
  // Verify chain ID
  const network = await provider.getNetwork();
  console.log('Connected to chain ID:', network.chainId);
  
  // Create wallet
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  
  // Send test transaction
  const tx = await wallet.sendTransaction({
    to: '0x0000000000000000000000000000000000000000',
    value: ethers.utils.parseEther('0.001'),
    chainId: 9000 // Explicit chainId
  });
  
  console.log('Transaction sent:', tx.hash);
  console.log('Transaction chainId:', tx.chainId); // Should be 9000
  
  const receipt = await tx.wait();
  console.log('Transaction confirmed in block:', receipt.blockNumber);
}

testSigning().catch(console.error);
```

## Genesis Configuration

### Setting EVM Chain ID in Genesis

The EVM chain ID is configured in the genesis file under `app_state.evm.params.chain_config.chain_id`:

```json
{
  "app_state": {
    "evm": {
      "params": {
        "evm_denom": "uflora",
        "enable_create": true,
        "enable_call": true,
        "chain_config": {
          "chain_id": "766999", // EVM chain ID (string decimal)
          "homestead_block": "0",
          "eip155_block": "0",
          // ... other EIP blocks
        }
      }
    }
  }
}
```

### Update Script for Regenesis

```bash
#!/bin/bash
# update_evm_chain_id.sh

GENESIS_FILE="$HOME/.flora/config/genesis.json"
NEW_EVM_CHAIN_ID="766999"

# Backup genesis
cp $GENESIS_FILE ${GENESIS_FILE}.backup

# Update EVM chain ID
cat $GENESIS_FILE | \
  jq ".app_state.evm.params.chain_config.chain_id = \"$NEW_EVM_CHAIN_ID\"" \
  > ${GENESIS_FILE}.tmp && \
  mv ${GENESIS_FILE}.tmp $GENESIS_FILE

# Verify
echo "Updated EVM chain ID to: $NEW_EVM_CHAIN_ID"
jq -r '.app_state.evm.params.chain_config.chain_id' $GENESIS_FILE
```

### Cosmos Chain ID

The Cosmos chain ID is separate and set at the top level:

```json
{
  "chain_id": "flora_7668378-1",  // Cosmos chain ID (stays same)
  "app_state": {
    "evm": {
      "params": {
        "chain_config": {
          "chain_id": "766999"  // EVM chain ID (changes)
        }
      }
    }
  }
}
```

**Important**: The Cosmos chain ID (`flora_7668378-1`) remains unchanged during EVM chain ID updates. Only the EVM chain ID in the genesis config changes.

## Quick Reference

### Chain ID Values

| Network | Cosmos Chain ID | EVM Chain ID (eth_chainId) | Network ID (net_version) |
|---------|-----------------|---------------------------|--------------------------|
| Current Devnet | flora_7668378-1 | 9000 (0x2328) | 7668378 |
| New Devnet | flora_7668378-1 | 766999 (0xBB417) | 7668378 |
| Mainnet (Reserved) | flora_7668378-1 | 766793 (0xBB349) | 7668378 |

### RPC Methods

| Method | Returns | Use For |
|--------|---------|---------|
| `eth_chainId` | Hex string (e.g., "0x2328") | **Transaction signing, wallet config** |
| `net_version` | Decimal string (e.g., "7668378") | **Network info only** |
| `eth_blockNumber` | Current block | Block queries |
| `eth_gasPrice` | Current gas price | Fee estimation |

### Best Practices

1. ✅ **Always use `eth_chainId` for wallet and signing configuration**
2. ✅ **Ignore `net_version` for EVM operations**
3. ✅ **Expect mismatch warnings in MetaMask** (safe to ignore)
4. ✅ **Test chain ID detection before production**
5. ✅ **Document chain ID clearly in user guides**
6. ❌ **Do not use `net_version` for EIP-155 signing**
7. ❌ **Do not expect `eth_chainId == net_version` on Cosmos EVM chains**

## References

- [EIP-155: Simple replay attack protection](https://eips.ethereum.org/EIPS/eip-155)
- [Evmos Chain ID Documentation](https://docs.evmos.org/protocol/concepts/chain-id)
- [Flora Chain ID Strategy](./CHAIN_ID_STRATEGY.md)
- [Flora Genesis Configuration](./GENESIS_CONFIG.md)
- [Flora Devnet Regenesis Plan](./plans/todo/0003-devnet-genesis-regenesis-plan.md)

## Troubleshooting Checklist

When experiencing EVM RPC issues:

- [ ] Verify `eth_chainId` returns expected value
- [ ] Confirm using `eth_chainId` (not `net_version`) in wallet config
- [ ] Check transaction `chainId` field matches `eth_chainId`
- [ ] Ensure genesis `app_state.evm.params.chain_config.chain_id` is correct
- [ ] Test with minimal transaction to isolate issue
- [ ] Check node logs for EVM module errors
- [ ] Verify EVM module is enabled in `app.toml`

## Support

If issues persist after following this guide:
1. Check node logs: `journalctl -u florad -f`
2. Verify EVM config: `florad query evm params`
3. Test with different wallet (e.g., Rabby, Frame)
4. Open issue with RPC request/response details
