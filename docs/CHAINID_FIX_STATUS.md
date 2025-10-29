# Flora EVM Chain ID Fix - Status Report

## The Problem
- **Issue**: EVM returning chain ID 9000 instead of 766999
- **Root Cause**: Hardcoded `ChainID = "localchain_9000-1"` in app/app.go
- **Impact**: Conflicts with Evmos testnet, wrong chain ID for wallets

## The Solution

### 1. Code Changes Applied ✅
```go
// app/app.go - BEFORE
ChainID = "localchain_9000-1"
BaseDenom = "petal"
DisplayDenom = "MY_DENOM_DISPLAY"

// app/app.go - AFTER
ChainID = "flora_766999-1"
BaseDenom = "uflora"
DisplayDenom = "FLORA"
```

### 2. Critical Discovery
The Evmos EVM module **always** extracts the numeric part from the Cosmos chain-id:
- `flora_766999-1` → EVM chain ID: 766999 ✅
- `flora_7668378-1` → EVM chain ID: 7668378 (conflicts)
- `localchain_9000-1` → EVM chain ID: 9000 (what we had)

## Current Status

### ⚠️ Architecture Issue
- **Problem**: Mac binaries deployed to Linux nodes
- **All binaries on nodes are Mach-O ARM64 format (Mac)**
- **Nodes need Linux x86_64 binaries**

### 🔧 Solution in Progress
1. Building Linux binary using Docker (golang:1.23-alpine)
2. Will deploy Linux binary to all nodes
3. Regenesis with chain-id `flora_766999-1`

## Required Steps

### Once Linux Binary is Built:

1. **Deploy to nodes**:
```bash
scp build/florad-linux ubuntu@[node]:~/florad
sudo mv ~/florad /usr/local/bin/
```

2. **Regenesis with correct chain ID**:
```bash
florad init [moniker] --chain-id flora_766999-1
```

3. **Verify fix**:
```bash
# Should return 0xbb417 (766999)
curl -X POST http://[node]:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
```

## Key Insight
**The chain-id string IS the source of the EVM chain ID**. No genesis config needed - just use `flora_766999-1` as the Cosmos chain-id.

## Files Created
- `/scripts/deploy_fix_766999.sh` - Full deployment script
- `/scripts/simple_regenesis_766999.sh` - Simple regenesis
- `/docs/FIX_EVM_CHAINID_766999.md` - Complete solution docs
- `Dockerfile.linux` - Docker build for Linux binary

## Next Actions
1. ⏳ Wait for Docker build to complete
2. Extract Linux binary from container
3. Deploy to nodes
4. Execute regenesis with `flora_766999-1`
5. Verify EVM chain ID is 766999

---
**Status**: Building Linux binary in Docker
**Target**: EVM Chain ID 766999
**Method**: Use Cosmos chain-id `flora_766999-1`