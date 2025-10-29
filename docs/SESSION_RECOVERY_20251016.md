# SESSION RECOVERY - Flora Devnet Regenesis (October 16, 2025)

## CRITICAL INFORMATION FOR SESSION RECOVERY

### SSH Access (ESSENTIAL)
```bash
KEY=~/.ssh/esprezzo/norcal-pub.pem
ssh -i $KEY ubuntu@52.9.17.25      # Genesis (lead) node
ssh -i $KEY ubuntu@50.18.34.12     # Guardian node
ssh -i $KEY ubuntu@204.236.162.240  # Nexus node
```

## CURRENT STATE (AS OF OCT 16, 16:54 UTC)

### What's Running
- **Genesis node (52.9.17.25)**: Fresh init completed, gentx created with EMPTY delegator_address
  - Validator address: flora1yrm9yelmhdwzcgxr7wqu6t3q73zw3jy3f5r8jv
  - Node ID: 487edf21f86b8d4fb0eb55cfbf308f90630c63ee
  - Status: Waiting for other gentx files

- **Guardian node (50.18.34.12)**: Previous gentx with repaired delegator (INVALID - needs fresh)
  - Status: Needs fresh init and gentx WITHOUT repair

- **Nexus node (204.236.162.240)**: Previous gentx with repaired delegator (INVALID - needs fresh)
  - Status: Needs fresh init and gentx WITHOUT repair

### Critical Discovery (MOST IMPORTANT)
**Empty delegator_address is NOT the problem!**
- Old working gentx from July 2025: `~/.flora.backup-20250725-180306/config/gentx/gentx-448ba973f8513215f556420cb779f749afe631d3.json`
- **This old working gentx ALSO has empty delegator_address: ""**
- The chain ran successfully for MONTHS with empty delegator_address
- The repair_gentx.sh script that adds delegator_address actually BREAKS the signatures
- Solution: Use empty delegator_address as it always has been

## TODO LIST STATUS

1. ✅ Test local gentx generation
2. ✅ Analyze gentx output for delegator_address
3. ✅ Find root cause of gentx issue
4. ✅ Investigate why validator set is empty
5. ✅ Create fresh gentx without repair on all nodes (Genesis done, others pending)
6. ⏳ **NEXT**: Collect gentx and complete genesis on lead node
7. ⏳ Start chain with empty delegator_address as it always has been
8. ⏳ Verify eth_chainId returns 0xBB417
9. ⏳ Bring explorer online

## EXACT NEXT STEPS TO COMPLETE REGENESIS

### Step 1: Complete fresh gentx on Guardian and Nexus (NO REPAIR!)
```bash
KEY=~/.ssh/esprezzo/norcal-pub.pem

# On Guardian (50.18.34.12)
ssh -i $KEY ubuntu@50.18.34.12 'bash -s' << 'EOF'
sudo systemctl stop florad || true
rm -rf ~/.flora
florad init Flora-Guardian --chain-id flora_766999-1
# Set denoms
GENESIS=~/.flora/config/genesis.json
jq '.app_state.staking.params.bond_denom = "uflora"' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"
jq '.app_state.mint.params.mint_denom = "uflora"' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"
jq '.app_state.crisis.constant_fee.denom = "uflora"' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"
jq '.app_state.evm.params.evm_denom = "uflora"' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"
# Create key and gentx
echo -e "y\n" | florad keys add validator --keyring-backend test
florad genesis add-genesis-account validator 10000000000000000000000000uflora --keyring-backend test
florad genesis gentx validator 1000000000000000000000000uflora \
  --chain-id flora_766999-1 \
  --moniker Flora-Guardian \
  --keyring-backend test
# DO NOT REPAIR - leave delegator_address empty!
EOF

# Same for Nexus (204.236.162.240) - just change moniker to Flora-Nexus
```

### Step 2: Copy gentx files to Genesis
```bash
KEY=~/.ssh/esprezzo/norcal-pub.pem
# Copy from Guardian
scp -i $KEY ubuntu@50.18.34.12:~/.flora/config/gentx/gentx-*.json /tmp/gentx-guardian.json
scp -i $KEY /tmp/gentx-guardian.json ubuntu@52.9.17.25:~/.flora/config/gentx/

# Copy from Nexus
scp -i $KEY ubuntu@204.236.162.240:~/.flora/config/gentx/gentx-*.json /tmp/gentx-nexus.json
scp -i $KEY /tmp/gentx-nexus.json ubuntu@52.9.17.25:~/.flora/config/gentx/
```

### Step 3: Complete genesis on lead node
```bash
KEY=~/.ssh/esprezzo/norcal-pub.pem
ssh -i $KEY ubuntu@52.9.17.25 'bash -s' << 'EOF'
GENESIS=~/.flora/config/genesis.json

# Add other validator accounts (get addresses from their nodes first)
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

### Step 4: Distribute genesis and set peers
```bash
KEY=~/.ssh/esprezzo/norcal-pub.pem
# Copy genesis to other nodes
scp -i $KEY ubuntu@52.9.17.25:~/.flora/config/genesis.json /tmp/
scp -i $KEY /tmp/genesis.json ubuntu@50.18.34.12:~/.flora/config/genesis.json
scp -i $KEY /tmp/genesis.json ubuntu@204.236.162.240:~/.flora/config/genesis.json

# Get node IDs and set persistent_peers (run on each node)
```

### Step 5: Start services
```bash
KEY=~/.ssh/esprezzo/norcal-pub.pem
# Start all nodes
ssh -i $KEY ubuntu@52.9.17.25 'sudo systemctl start florad'
ssh -i $KEY ubuntu@50.18.34.12 'sudo systemctl start florad'
ssh -i $KEY ubuntu@204.236.162.240 'sudo systemctl start florad'
```

## KEY FILES AND THEIR PURPOSE

### Documentation
- `docs/REGENESIS_STATUS_REPORT.md` - Complete status with execution logs
- `docs/HANDOFF_TO_NEXT_AGENT.md` - Quick reference for next agent
- `docs/plans/issues/0005-devnet-regenesis-blockers.md` - Detailed issue analysis with CRITICAL DISCOVERY
- `docs/plans/issues/0006-explorer-wallet-bringup.md` - Explorer/wallet requirements
- `docs/plans/runbooks/DEVNET_EIP155_POLISH_RUNBOOK.md` - Complete EIP-155 runbook

### Scripts (all in scripts/ directory)
- `quick_regenesis_766999.sh` - Main regenesis script (UPDATED with denoms pre-gentx)
- `repair_gentx.sh` - DO NOT USE - this breaks signatures!
- `enable_jsonrpc_rest.sh` - Enable APIs in app.toml
- `verify_eip155_polish.sh` - Verify eth_chainId after start
- `remote_eip155_polish_driver.sh` - Orchestrate across all nodes

## ENVIRONMENT DETAILS

### Network Configuration
- **Cosmos chain-id**: flora_766999-1
- **EVM chain-id**: 766999 (0xBB417)
- **Native token**: uflora (18 decimals)
- **Nodes**: All Ubuntu 24.04.2 LTS on AWS EC2 (us-west-1)

### Required Allocations (Total 50M FLORA)
- 3 validators × 10M = 30M
- Faucet: 10M
- Dev pool: 1M
- Reserve: 9M

### Common Issues and Solutions
1. **Empty delegator_address**: NOT A PROBLEM - leave it empty!
2. **"validator set is empty"**: Usually means signatures are invalid from manual edits
3. **gRPC error on 1317**: That's REST port, gRPC uses 9090
4. **eth_chainId wrong**: Need eip155_block = "0" in genesis

## GIT STATUS
- Branch: regen
- Last commit: 0312c80 docs: investigate and document devnet regenesis blockers with EIP-155 solution
- Working directory: clean

## CRITICAL REMINDERS
1. DO NOT use repair_gentx.sh - it breaks everything!
2. Empty delegator_address is NORMAL and CORRECT
3. Set all denoms to uflora BEFORE creating gentx
4. Set eip155_block = "0" for correct eth_chainId
5. JSON-RPC must be enabled in app.toml for wallets to work

## IF STARTING FRESH
If you need to restart completely fresh, the root cause we discovered is:
- The `florad genesis gentx` command produces empty delegator_address (always has)
- This is NOT a bug - the chain has always worked this way
- Manual repairs to add delegator_address break the signatures
- Solution: Just use the gentx files as-is with empty delegator_address

The actual remaining work is simply:
1. Fresh gentx on Guardian and Nexus (WITHOUT repair)
2. Collect on Genesis with proper EIP-155 settings
3. Start the chain

## CONTACT
- SSH Key: ~/.ssh/esprezzo/norcal-pub.pem
- User: ubuntu
- Chain repo: https://github.com/flora-labs/flora
