# CURRENT STATE - Flora Devnet Regenesis
**Date**: October 16, 2025
**Time**: 17:30 UTC
**Status**: ✅ **COMPLETED** - 3-validator network running!

## 🎯 Quick Summary
Successfully resolved the gentx issue - empty `delegator_address` is NORMAL Cosmos SDK behavior. The real problem was simply that gentxs weren't being collected. Network is now running with 3 validators producing blocks.

## ✅ What's Completed
1. **Root cause identified**: Empty delegator_address is normal, not a bug
2. **All validators running**: 3/3 validators active and producing blocks
3. **Network fully operational**: Block height 29+ and climbing
4. **Token distribution complete**: 50M FLORA allocated as planned
5. **EIP-155 configured**: Chain ID 766999 set in genesis

## 📊 Live Network Status
- **Genesis Node (52.9.17.25)**: ✅ Active, 1M FLORA staked
- **Guardian Node (50.18.34.12)**: ✅ Active, 1M FLORA staked
- **Nexus Node (204.236.162.240)**: ✅ Active, 1M FLORA staked
- **Current Block Height**: 29+ (increasing)
- **Total Supply**: 50,000,016+ FLORA

## 📋 What Was Done (Complete Steps)
```bash
KEY=~/.ssh/esprezzo/norcal-pub.pem
ssh -i $KEY ubuntu@50.18.34.12 'bash -s' << 'EOF'
sudo systemctl stop florad || true
rm -rf ~/.flora
florad init Flora-Guardian --chain-id flora_766999-1

# Set denoms BEFORE gentx
GENESIS=~/.flora/config/genesis.json
jq '.app_state.staking.params.bond_denom = "uflora"' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"
jq '.app_state.mint.params.mint_denom = "uflora"' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"
jq '.app_state.crisis.constant_fee.denom = "uflora"' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"
jq '.app_state.evm.params.evm_denom = "uflora"' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"

# Create validator key and gentx
echo -e "y\n" | florad keys add validator --keyring-backend test
florad genesis add-genesis-account validator 10000000000000000000000000uflora --keyring-backend test
florad genesis gentx validator 1000000000000000000000000uflora \
  --chain-id flora_766999-1 \
  --moniker Flora-Guardian \
  --keyring-backend test
EOF
```

### 2. Create gentx on Nexus (5 minutes)
```bash
# Same as above but with moniker "Flora-Nexus"
KEY=~/.ssh/esprezzo/norcal-pub.pem
ssh -i $KEY ubuntu@204.236.162.240 'bash -s' << 'EOF'
# ... same commands with Flora-Nexus moniker ...
EOF
```

### 3. Collect gentx files on Genesis (10 minutes)
```bash
KEY=~/.ssh/esprezzo/norcal-pub.pem

# Copy gentx from Guardian
scp -i $KEY ubuntu@50.18.34.12:~/.flora/config/gentx/gentx-*.json /tmp/gentx-guardian.json
scp -i $KEY /tmp/gentx-guardian.json ubuntu@52.9.17.25:~/.flora/config/gentx/

# Copy gentx from Nexus
scp -i $KEY ubuntu@204.236.162.240:~/.flora/config/gentx/gentx-*.json /tmp/gentx-nexus.json
scp -i $KEY /tmp/gentx-nexus.json ubuntu@52.9.17.25:~/.flora/config/gentx/

# Complete genesis on lead node
ssh -i $KEY ubuntu@52.9.17.25 'bash -s' << 'EOF'
GENESIS=~/.flora/config/genesis.json

# Add faucet, dev pool, reserve accounts
florad keys add faucet --keyring-backend test 2>/dev/null || true
florad keys add devpool --keyring-backend test 2>/dev/null || true
florad keys add reserve --keyring-backend test 2>/dev/null || true
FAUCET=$(florad keys show faucet -a --keyring-backend test)
DEVPOOL=$(florad keys show devpool -a --keyring-backend test)
RESERVE=$(florad keys show reserve -a --keyring-backend test)

florad genesis add-genesis-account $FAUCET 10000000000000000000000000uflora --keyring-backend test
florad genesis add-genesis-account $DEVPOOL 1000000000000000000000000uflora --keyring-backend test
florad genesis add-genesis-account $RESERVE 9000000000000000000000000uflora --keyring-backend test

# Set EVM chain config for EIP-155
jq '.app_state.evm.params.chain_config.chain_id = "766999"' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"
jq '.app_state.evm.params.chain_config.eip155_block = "0"' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"

# Collect and validate
florad genesis collect-gentxs
florad genesis validate

# Enable JSON-RPC and REST
APP=~/.flora/config/app.toml
sed -i 's/enable = false/enable = true/g' $APP
sed -i 's/address = "localhost:8545"/address = "0.0.0.0:8545"/' $APP
sed -i 's/address = "tcp:\/\/localhost:1317"/address = "tcp:\/\/0.0.0.0:1317"/' $APP
EOF
```

### 4. Distribute genesis and start (10 minutes)
```bash
KEY=~/.ssh/esprezzo/norcal-pub.pem

# Copy genesis to other nodes
scp -i $KEY ubuntu@52.9.17.25:~/.flora/config/genesis.json /tmp/
scp -i $KEY /tmp/genesis.json ubuntu@50.18.34.12:~/.flora/config/genesis.json
scp -i $KEY /tmp/genesis.json ubuntu@204.236.162.240:~/.flora/config/genesis.json

# Set persistent peers and start all nodes
ssh -i $KEY ubuntu@52.9.17.25 'sudo systemctl start florad'
ssh -i $KEY ubuntu@50.18.34.12 'sudo systemctl start florad'
ssh -i $KEY ubuntu@204.236.162.240 'sudo systemctl start florad'
```

### 5. Verify success (5 minutes)
```bash
# Check eth_chainId returns 0xBB417
curl -s -X POST http://52.9.17.25:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' | jq -r '.result'
# Expected: 0xbb417

# Check block production
curl -s http://52.9.17.25:26657/status | jq '.result.sync_info.latest_block_height'
# Expected: Increasing block height
```

## ⚠️ Critical Reminders

### DO NOT DO THESE:
- ❌ **DO NOT** use `repair_gentx.sh` - it breaks signatures!
- ❌ **DO NOT** manually edit gentx files
- ❌ **DO NOT** add delegator_address to gentx
- ❌ **DO NOT** rebuild the binary (it's fine!)
- ❌ **DO NOT** panic about empty delegator_address

### DO THESE:
- ✅ **DO** create gentx with empty delegator_address (normal)
- ✅ **DO** set all denoms to "uflora" BEFORE creating gentx
- ✅ **DO** set EIP-155 config (eip155_block = "0")
- ✅ **DO** enable JSON-RPC and REST in app.toml

## 📊 Expected Results
- **Chain ID (Cosmos)**: flora_766999-1
- **Chain ID (EVM)**: 766999 (0xBB417)
- **Total Supply**: 50,000,000 FLORA
- **Validators**: 3 active
- **Block Time**: ~5 seconds
- **Explorer**: Will connect once chain starts

## 🔑 Access Information
```bash
# SSH Key
KEY=~/.ssh/esprezzo/norcal-pub.pem

# Nodes
Genesis:  ssh -i $KEY ubuntu@52.9.17.25
Guardian: ssh -i $KEY ubuntu@50.18.34.12
Nexus:    ssh -i $KEY ubuntu@204.236.162.240

# Endpoints (after start)
Tendermint RPC: http://[IP]:26657
EVM JSON-RPC:   http://[IP]:8545
REST API:       http://[IP]:1317
```

## 📚 Key Documentation
- `docs/SESSION_RECOVERY_20251016.md` - Complete recovery guide
- `docs/HANDOFF_TO_NEXT_AGENT.md` - Updated handoff with discovery
- `docs/plans/issues/0005-devnet-regenesis-blockers.md` - Root cause analysis
- `scripts/quick_regenesis_766999.sh` - Automation script (ready)

## 🚀 Time Estimate
- Guardian gentx: 5 minutes
- Nexus gentx: 5 minutes
- Collect & finalize: 10 minutes
- Start chain: 5 minutes
- Verify: 5 minutes
- **TOTAL: ~30 minutes to completion**

## 💡 Key Discovery & Resolution
The breakthrough was finding an old working gentx from July 2025 that ALSO had empty delegator_address. This proved the chain has always worked this way. The REAL issue was that `florad genesis collect-gentxs` hadn't been run. Once we ran this simple command, everything worked perfectly!

## 🚀 Final Network Configuration
```yaml
Network: 3-validator Flora devnet
Cosmos Chain ID: flora_766999-1
EVM Chain ID: 766999 (0xBB417)
Status: OPERATIONAL
Block Height: 29+ (increasing)
Validators: 3/3 active
Total Supply: 50,000,016+ FLORA
```

## 📡 Live Endpoints
```bash
# Tendermint RPC
http://52.9.17.25:26657
http://50.18.34.12:26657
http://204.236.162.240:26657

# EVM JSON-RPC
http://52.9.17.25:8545
http://50.18.34.12:8545
http://204.236.162.240:8545

# REST API
http://52.9.17.25:1317
http://50.18.34.12:1317
http://204.236.162.240:1317
```

---
**Last Updated**: October 16, 2025 17:30 UTC
**Status**: ✅ COMPLETE - Network operational
