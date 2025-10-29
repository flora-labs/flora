# Fix for EVM Chain ID 766999 - Implementation Complete

## Problem Solved
The EVM was returning chain ID 9000 instead of 766999 because of hardcoded defaults in the Flora source code.

## Root Cause
1. **Hardcoded Chain ID**: `app/app.go` had `ChainID = "localchain_9000-1"`
2. **Wrong Denoms**: Base denom was "petal" instead of "uflora"
3. **Evmos Behavior**: The EVM module extracts the numeric part from Cosmos chain-id

## Changes Made

### 1. Updated app/app.go
```go
// Before:
ChainID = "localchain_9000-1"
BaseDenom = "petal"
DisplayDenom = "MY_DENOM_DISPLAY"

// After:
ChainID = "flora_766999-1"
BaseDenom = "uflora"
DisplayDenom = "FLORA"
```

### 2. Updated app/config.go
Added support for multiple Flora chain IDs:
- `flora_7668378-1` (current devnet)
- `flora_7668378` (prefix)
- `flora_766999` (new devnet with correct EVM ID)

## Critical Discovery About Evmos

The Evmos EVM module **ALWAYS** derives the EVM chain ID from the Cosmos chain-id string by extracting the numeric part. This means:

- `flora_7668378-1` → EVM chain ID: 7668378
- `flora_766999-1` → EVM chain ID: 766999
- `localchain_9000-1` → EVM chain ID: 9000

## Next Steps for Regenesis

To properly implement chain ID 766999, you have two options:

### Option 1: Full Regenesis with New Chain ID (Recommended)
Use Cosmos chain-id: `flora_766999-1`

This ensures the EVM automatically uses 766999 as the chain ID.

```bash
# Initialize with correct chain-id
florad init [moniker] --chain-id flora_766999-1

# The EVM will automatically use 766999
```

### Option 2: Keep Current Chain ID (Not Recommended)
Continue using `flora_7668378-1` but this will result in EVM chain ID 7668378, which conflicts with QL1 testnet.

## Binary Updates Required

The new binary (just built) includes:
- Correct default chain ID support
- Proper uflora/FLORA denominations
- Support for flora_766999-1 chain ID

### Deployment Steps

1. **Stop current nodes**:
```bash
ssh -i ~/.ssh/esprezzo/norcal-pub.pem ubuntu@52.9.17.25
sudo systemctl stop florad
```

2. **Deploy new binary**:
```bash
# Copy new binary to nodes
scp -i ~/.ssh/esprezzo/norcal-pub.pem build/florad ubuntu@52.9.17.25:~/
scp -i ~/.ssh/esprezzo/norcal-pub.pem build/florad ubuntu@50.18.34.12:~/
scp -i ~/.ssh/esprezzo/norcal-pub.pem build/florad ubuntu@204.236.162.240:~/

# Install on each node
ssh -i ~/.ssh/esprezzo/norcal-pub.pem ubuntu@52.9.17.25 'sudo mv ~/florad /usr/local/bin/ && sudo chmod +x /usr/local/bin/florad'
```

3. **Perform regenesis with new chain-id**:
```bash
# Clear old data
rm -rf ~/.flora

# Init with NEW chain-id for proper EVM chain ID
florad init [moniker] --chain-id flora_766999-1

# Continue with normal genesis setup...
```

## Important Notes

1. **Genesis Configuration**: The `evm.params.chain_config.chain_id` in genesis.json is **IGNORED** by Evmos
2. **Chain ID Source**: The EVM chain ID comes from the Cosmos chain-id string
3. **Binary Compatibility**: The new binary supports both old and new chain IDs

## Verification After Deployment

```bash
# Check EVM chain ID (should return 0xbb417 = 766999)
curl -X POST http://[node]:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'

# Check Cosmos chain ID
curl http://[node]:26657/status | jq -r '.result.node_info.network'
```

## Summary

**Before**: EVM chain ID was 9000 due to hardcoded "localchain_9000-1"
**After**: EVM chain ID will be 766999 with chain-id "flora_766999-1"

The fix is complete in the source code. Now you need to:
1. Deploy the new binary
2. Regenesis with chain-id `flora_766999-1`
3. The EVM will automatically use chain ID 766999