# Devnet Genesis & Regenesis Plan

**Status**: approved  
**Owner**: chain-core  
**Created**: 2025-10-15  
**Related**: 0001-runbook-evm-chainid-renumbering-regenesis.md, GENESIS_CONFIG.md, chain_metadata.json

## Summary

Complete genesis configuration and regenesis plan for Flora Devnet with new EVM chain ID 766999 (0xbb3e7). Includes validator allocations, total supply, and coordinated genesis script for all 3 validators.

## Genesis Parameters

### Chain Configuration
```
Cosmos Chain ID: flora_7668378-1
EVM Chain ID: 766999 (0xbb3e7)
Genesis Time: TBD (coordinated launch)
Network Name: Flora Devnet
```

### Total Supply
```
Total Supply: 50,000,000,000,000,000,000,000,000 uflora (50 million FLORA)
Decimal Places: 18
Display Denom: flora
Base Denom: uflora
```

## Token Allocation Strategy

### Devnet Distribution (Simple - No Vesting)

| Allocation | Amount (FLORA) | Amount (uflora) | Purpose |
|------------|----------------|-----------------|---------|
| Validator 1 (Flora-Genesis) | 10,000,000 | 10000000000000000000000000 | Genesis validator + testing |
| Validator 2 (Flora-Guardian) | 10,000,000 | 10000000000000000000000000 | Genesis validator + testing |
| Validator 3 (Flora-Nexus) | 10,000,000 | 10000000000000000000000000 | Genesis validator + testing |
| Faucet/Community | 10,000,000 | 10000000000000000000000000 | Public faucet for testing |
| Development Pool | 1,000,000 | 1000000000000000000000000 | Team testing & development |
| Reserve/Future | 9,000,000 | 9000000000000000000000000 | Unallocated reserve |
| **Total** | **50,000,000** | **50000000000000000000000000** | |

### Validator Self-Stake

Each validator will self-stake:
```
Self-Stake: 1,000,000 FLORA (1000000000000000000000000 uflora)
Remaining Balance: 9,000,000 FLORA
```

## Validator Addresses

### Pre-Generated Keys (for coordinated genesis)

Each validator node will need:
- Validator operator address (floravaloper...)
- Delegator address (flora...)
- Node ID (for persistent peers)

**Action Required**: Generate keys on each node before genesis coordination.

## Genesis Creation Process

### Phase 1: Local Genesis Preparation (Each Validator)

```bash
#!/bin/bash
# Run on each validator node

CHAIN_ID="flora_7668378-1"
MONIKER="Flora-Genesis"  # Change per node: Flora-Genesis, Flora-Guardian, Flora-Nexus
KEYRING="test"

# Initialize node
florad init $MONIKER --chain-id $CHAIN_ID

# Generate or recover validator key
florad keys add validator --keyring-backend $KEYRING

# Get validator address
VALIDATOR_ADDR=$(florad keys show validator -a --keyring-backend $KEYRING)
echo "Validator Address: $VALIDATOR_ADDR"

# Add genesis account with 10M FLORA
florad genesis add-genesis-account $VALIDATOR_ADDR 10000000000000000000000000uflora

# Create genesis transaction (self-stake 1M FLORA)
florad genesis gentx validator 1000000000000000000000000uflora \
  --chain-id $CHAIN_ID \
  --moniker $MONIKER \
  --commission-rate="0.10" \
  --commission-max-rate="0.20" \
  --commission-max-change-rate="0.01" \
  --min-self-delegation="1" \
  --keyring-backend $KEYRING

# Gentx file created at: ~/.flora/config/gentx/gentx-*.json
```

### Phase 2: Genesis Coordination (Lead Validator)

**Lead Node**: Flora-Genesis (52.9.17.25)

```bash
#!/bin/bash
# Run on Flora-Genesis node after collecting all gentx files

CHAIN_ID="flora_7668378-1"

# Step 1: Collect gentx files from other validators
# Copy gentx-guardian.json and gentx-nexus.json to ~/.flora/config/gentx/

# Step 2: Add additional genesis accounts (faucet, dev pool)
# Faucet account
florad genesis add-genesis-account flora1faucet... 10000000000000000000000000uflora

# Development pool
florad genesis add-genesis-account flora1devpool... 1000000000000000000000000uflora

# Step 3: Collect all genesis transactions
florad genesis collect-gentxs

# Step 4: Update genesis with EVM chain ID 766999
update_genesis() {
  cat $HOME/.flora/config/genesis.json | \
    jq "$1" > $HOME/.flora/config/tmp_genesis.json && \
    mv $HOME/.flora/config/tmp_genesis.json $HOME/.flora/config/genesis.json
}

# Set EVM chain ID
update_genesis '.app_state["evm"]["params"]["chain_config"]["chain_id"]="766999"'

# Verify EVM configuration
update_genesis '.app_state["evm"]["params"]["evm_denom"]="uflora"'
update_genesis '.app_state["evm"]["params"]["enable_create"]=true'
update_genesis '.app_state["evm"]["params"]["enable_call"]=true'

# Set fee market params for devnet
update_genesis '.app_state["feemarket"]["params"]["base_fee"]="1000000000"'
update_genesis '.app_state["feemarket"]["params"]["no_base_fee"]=false'

# Step 5: Validate genesis
florad genesis validate-genesis

# Step 6: Calculate SHA256 hash for verification
sha256sum ~/.flora/config/genesis.json

# Step 7: Distribute genesis.json to all validators
```

### Phase 3: Genesis Distribution

```bash
# Copy final genesis.json to all validator nodes

# From Flora-Genesis to Flora-Guardian
scp -i ~/.ssh/esprezzo/norcal-pub.pem \
  ~/.flora/config/genesis.json \
  ubuntu@50.18.34.12:~/.flora/config/genesis.json

# From Flora-Genesis to Flora-Nexus
scp -i ~/.ssh/esprezzo/norcal-pub.pem \
  ~/.flora/config/genesis.json \
  ubuntu@204.236.162.240:~/.flora/config/genesis.json
```

### Phase 4: Verify Genesis Hash (All Validators)

```bash
# Each validator must verify they have the same genesis
sha256sum ~/.flora/config/genesis.json

# All nodes should show the SAME hash
# Example: a1b2c3d4... genesis.json
```

### Phase 5: Configure Persistent Peers (All Validators)

```bash
# Get node IDs
NODE1_ID=$(florad tendermint show-node-id)  # Flora-Genesis
NODE2_ID=$(florad tendermint show-node-id)  # Flora-Guardian
NODE3_ID=$(florad tendermint show-node-id)  # Flora-Nexus

# Update config.toml with persistent peers
# Flora-Genesis (52.9.17.25):
# persistent_peers = "NODE2_ID@50.18.34.12:26656,NODE3_ID@204.236.162.240:26656"

# Flora-Guardian (50.18.34.12):
# persistent_peers = "NODE1_ID@52.9.17.25:26656,NODE3_ID@204.236.162.240:26656"

# Flora-Nexus (204.236.162.240):
# persistent_peers = "NODE1_ID@52.9.17.25:26656,NODE2_ID@50.18.34.12:26656"
```

### Phase 6: Coordinated Start

```bash
# Set genesis time in genesis.json (all nodes must match)
# For example: 2025-10-20T00:00:00Z

# Start all validators at the same time
sudo systemctl start florad

# Or if not using systemd:
florad start --log_level info
```

## Verification Steps

### After Genesis Launch

```bash
# 1. Check node is producing blocks
florad status | jq '.SyncInfo.latest_block_height'

# 2. Verify EVM chain ID
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  http://localhost:8545 | jq -r '.result'
# Expected: 0xbb3e7

# 3. Check validator is active
florad query staking validators

# 4. Verify total supply
florad query bank total

# 5. Check peer connections
curl -s localhost:26657/net_info | jq '.result.n_peers'
# Expected: 2 (for each validator)
```

## Genesis Script Template

```bash
#!/bin/bash
# genesis_devnet_766999.sh - Complete devnet genesis with chain ID 766999

set -e

CHAIN_ID="flora_7668378-1"
EVM_CHAIN_ID="766999"
GENESIS_TIME="2025-10-20T00:00:00Z"  # UPDATE THIS
KEYRING="test"

# Validator configurations
declare -A VALIDATORS=(
  ["genesis"]="Flora-Genesis"
  ["guardian"]="Flora-Guardian"
  ["nexus"]="Flora-Nexus"
)

# Step 1: Initialize
echo "Initializing Flora Devnet..."
florad init ${VALIDATORS[$1]} --chain-id $CHAIN_ID

# Step 2: Create/recover validator key
florad keys add validator --keyring-backend $KEYRING

# Step 3: Add genesis account (10M FLORA)
VALIDATOR_ADDR=$(florad keys show validator -a --keyring-backend $KEYRING)
florad genesis add-genesis-account $VALIDATOR_ADDR 10000000000000000000000000uflora

# Step 4: Create gentx (stake 1M FLORA)
florad genesis gentx validator 1000000000000000000000000uflora \
  --chain-id $CHAIN_ID \
  --moniker ${VALIDATORS[$1]} \
  --commission-rate="0.10" \
  --commission-max-rate="0.20" \
  --commission-max-change-rate="0.01" \
  --min-self-delegation="1" \
  --keyring-backend $KEYRING

echo "✅ Genesis transaction created for ${VALIDATORS[$1]}"
echo "📝 Gentx location: ~/.flora/config/gentx/"
echo "📤 Share this gentx with the lead validator"
```

## Faucet Setup (Post-Genesis)

### Faucet Account Management

```bash
# Generate faucet key
florad keys add faucet --keyring-backend test

# Get faucet address (should match genesis allocation)
FAUCET_ADDR=$(florad keys show faucet -a --keyring-backend test)

# Verify faucet balance
florad query bank balances $FAUCET_ADDR

# Faucet send example (for testing)
florad tx bank send faucet flora1... 1000000000000000000uflora \
  --chain-id flora_7668378-1 \
  --keyring-backend test \
  --fees 1000000000000000uflora
```

## Emergency Procedures

### Genesis Restart Required

If genesis fails and needs restart:

```bash
# 1. Stop all nodes
sudo systemctl stop florad

# 2. Reset chain data (on all nodes)
florad tendermint unsafe-reset-all

# 3. Remove old genesis
rm ~/.flora/config/genesis.json

# 4. Restart from Phase 1
```

### Validator Key Recovery

```bash
# Export validator key (backup)
florad keys export validator --keyring-backend test

# Import validator key (restore)
florad keys import validator exported_key.json --keyring-backend test
```

## Post-Regenesis Checklist

- [ ] All 3 validators running and producing blocks
- [ ] EVM chain ID verified as 766999 (0xbb3e7)
- [ ] Total supply matches: 50,000,000 FLORA
- [ ] Each validator has ~9M FLORA remaining (after 1M stake)
- [ ] Faucet account has 10M FLORA
- [ ] Development pool has 1M FLORA
- [ ] All nodes connected (2 peers each)
- [ ] EVM JSON-RPC responding on port 8545
- [ ] Tendermint RPC responding on port 26657
- [ ] MetaMask can connect with zero warnings

## Rollback Plan

If regenesis fails:

1. **Keep old chain running** until new chain is verified
2. **Test new genesis** on separate test instances first
3. **Announce downtime** before switching
4. **Backup old chain data**: `tar -czf old-chain-backup.tar.gz ~/.flora/`
5. **Document issues** encountered
6. **Retry with fixes** after team review

## Timeline Estimate

| Phase | Duration | Notes |
|-------|----------|-------|
| Key Generation | 15 min | Each validator generates keys |
| Gentx Creation | 15 min | Each validator creates gentx |
| Genesis Coordination | 30 min | Lead validator collects and finalizes |
| Genesis Distribution | 15 min | Copy to all nodes |
| Verification | 15 min | Hash checks and config updates |
| Coordinated Start | 5 min | All start simultaneously |
| **Total** | **~90 min** | Plus buffer for issues |

## Contact & Coordination

- **Genesis Lead**: Flora-Genesis (52.9.17.25)
- **Coordination Method**: SSH/SCP between nodes
- **Validation**: SHA256 hash comparison
- **Launch Window**: TBD (coordinate all validators)

## References

- `docs/GENESIS_CONFIG.md` - Complete genesis guide
- `docs/CHAIN_ID_STRATEGY.md` - Chain ID architecture
- `DEVNET.md` - Devnet deployment procedures
- `chain_metadata.json` - Network metadata

## Implementation Log

- 2025-10-15: Genesis plan created for devnet regenesis with chain ID 766999
- Pending: Execute regenesis during scheduled maintenance window
