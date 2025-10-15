# Pre-Regenesis Checklist

**Status**: Ready for Execution  
**Created**: 2025-10-15  
**Target**: Flora Devnet Regenesis with Chain ID 766999

## Overview

This checklist ensures all preparation is complete before executing the devnet regenesis to change the EVM chain ID from 9000 to 766999.

## ✅ Documentation Complete

- [x] Chain ID strategy documented (`docs/CHAIN_ID_STRATEGY.md`)
- [x] Regenesis runbook created (`docs/plans/todo/0001-runbook-evm-chainid-renumbering-regenesis.md`)
- [x] Client update task defined (`docs/plans/todo/0002-task-update-clients-to-new-chainid.md`)
- [x] Genesis plan with allocations (`docs/plans/todo/0003-devnet-genesis-regenesis-plan.md`)
- [x] EVM RPC troubleshooting guide (`docs/EVM_RPC_TROUBLESHOOTING.md`)
- [x] Chain metadata updated (`chain_metadata.json`)
- [x] RPC endpoints documented (`RPC_ENDPOINTS.md`, `RPC_SETUP.md`)
- [x] Project context updated (`CLAUDE.md`)

## ✅ Configuration Decided

- [x] Devnet EVM Chain ID: 766999 (0xbb3e7)
- [x] Mainnet Chain ID Reserved: 766793 (0xbb349)
- [x] Cosmos Chain ID: flora_7668378-1 (unchanged)
- [x] Total Supply: 1,000,000,000 FLORA (1 billion)
- [x] Token Distribution Plan:
  - [x] Validator 1 (Flora-Genesis): 100M FLORA
  - [x] Validator 2 (Flora-Guardian): 100M FLORA
  - [x] Validator 3 (Flora-Nexus): 100M FLORA
  - [x] Faucet: 500M FLORA
  - [x] Dev Pool: 200M FLORA
- [x] Validator Self-Stake: 10M FLORA each

## ⚠️ Pre-Execution Requirements

### Account Preparation

- [ ] **Generate faucet account**
  ```bash
  florad keys add faucet --keyring-backend test
  FAUCET_ADDR=$(florad keys show faucet -a --keyring-backend test)
  echo "Faucet address: $FAUCET_ADDR"
  # Save this address for genesis
  ```

- [ ] **Generate dev pool account**
  ```bash
  florad keys add devpool --keyring-backend test
  DEVPOOL_ADDR=$(florad keys show devpool -a --keyring-backend test)
  echo "Dev pool address: $DEVPOOL_ADDR"
  # Save this address for genesis
  ```

- [ ] **Backup account mnemonics** (store securely)
  ```bash
  # Export and save mnemonics offline
  florad keys export faucet --keyring-backend test
  florad keys export devpool --keyring-backend test
  ```

### Validator Coordination

- [ ] **Confirm all 3 validators available**
  - [ ] Flora-Genesis (52.9.17.25) - Lead validator
  - [ ] Flora-Guardian (50.18.34.12)
  - [ ] Flora-Nexus (204.236.162.240)

- [ ] **SSH access verified**
  ```bash
  ssh -i ~/.ssh/esprezzo/norcal-pub.pem ubuntu@52.9.17.25 "echo OK"
  ssh -i ~/.ssh/esprezzo/norcal-pub.pem ubuntu@50.18.34.12 "echo OK"
  ssh -i ~/.ssh/esprezzo/norcal-pub.pem ubuntu@204.236.162.240 "echo OK"
  ```

- [ ] **Schedule coordination call** (all validators)
  - Date: _______________
  - Time: _______________
  - Duration: 2 hours (90min work + buffer)

### Backup Current State

- [ ] **Export current chain state**
  ```bash
  # On each validator
  florad export > old-chain-export-$(date +%Y%m%d).json
  ```

- [ ] **Backup validator keys**
  ```bash
  # On each validator
  tar -czf validator-backup-$(date +%Y%m%d).tar.gz \
    ~/.flora/config/priv_validator_key.json \
    ~/.flora/config/node_key.json \
    ~/.flora/data/priv_validator_state.json
  ```

- [ ] **Backup chain data** (optional, disk space permitting)
  ```bash
  # On each validator
  tar -czf chain-data-backup-$(date +%Y%m%d).tar.gz ~/.flora/data/
  ```

- [ ] **Document current state**
  ```bash
  # Save current status
  curl -s http://52.9.17.25:26657/status | jq '.' > old-chain-status.json
  curl -s http://52.9.17.25:1317/cosmos/bank/v1beta1/supply > old-chain-supply.json
  ```

### Client Applications

- [ ] **Identify all client apps using the chain**
  - List web apps: _______________
  - List mobile apps: _______________
  - List scripts/tools: _______________

- [ ] **Prepare client update PRs** (see task 0002)
  - [ ] Update chain ID constants: 9000 → 766999
  - [ ] Update chain ID hex: 0x2328 → 0xbb3e7
  - [ ] Update MetaMask configs
  - [ ] Update RPC endpoint URLs (if changing)
  - [ ] Test updates on staging

- [ ] **Coordinate deployment**
  - Client deploy window: _______________
  - Rollback plan: _______________

### Communication Plan

- [ ] **Draft user announcement**
  - [ ] Maintenance window notice
  - [ ] Downtime duration estimate
  - [ ] What users need to do (remove old network, add new)
  - [ ] New chain ID instructions
  - [ ] Support contact info

- [ ] **Send advance notice** (minimum 48 hours)
  - [ ] Discord announcement
  - [ ] Twitter/X post
  - [ ] Email to known users (if applicable)
  - [ ] Update status page

- [ ] **Prepare FAQ**
  - [ ] Why chain ID is changing
  - [ ] How to update MetaMask
  - [ ] What happens to balances (reset for devnet)
  - [ ] When network will be back
  - [ ] Link to troubleshooting guide

### Infrastructure

- [ ] **DNS configuration ready** (if updating)
  - [ ] rpc.devnet.flora.network → TBD
  - [ ] api.devnet.flora.network → TBD
  - [ ] TTL set to 60 seconds for quick updates

- [ ] **Load balancer configured** (if using)
  - [ ] AWS ALB target group created
  - [ ] Health checks configured
  - [ ] HTTPS certificates ready

- [ ] **Monitoring tools ready**
  - [ ] Block explorer updated/reset (if applicable)
  - [ ] Metrics dashboard configured
  - [ ] Alert notifications enabled

## 🔧 Execution Day Preparation

### T-1 Day (Day Before)

- [ ] **Final coordination call**
  - [ ] Confirm all validators ready
  - [ ] Review execution steps
  - [ ] Assign roles (lead, backup, observer)
  - [ ] Test communication channels

- [ ] **Stage genesis script**
  ```bash
  # Copy genesis script to all validators
  scp genesis_devnet_766999.sh ubuntu@52.9.17.25:~/
  scp genesis_devnet_766999.sh ubuntu@50.18.34.12:~/
  scp genesis_devnet_766999.sh ubuntu@204.236.162.240:~/
  ```

- [ ] **Verify florad version**
  ```bash
  # On all validators - ensure same version
  florad version
  ```

- [ ] **Final backup verification**
  ```bash
  # Verify backups exist and are readable
  tar -tzf validator-backup-*.tar.gz | head
  ```

### T-0 (Execution Day)

- [ ] **Post maintenance notice** (2 hours before)
  - [ ] "Maintenance starting in 2 hours"
  - [ ] Link to status page
  - [ ] Estimated completion time

- [ ] **Final status check**
  ```bash
  # Ensure chain is healthy before shutdown
  curl -s http://52.9.17.25:26657/status | jq '.result.sync_info'
  ```

- [ ] **Open coordination channel** (Zoom/Discord/Slack)
  - [ ] All validators connected
  - [ ] Screen sharing ready
  - [ ] Emergency contacts available

## 📋 Execution Checklist (During Regenesis)

### Phase 1: Shutdown (5 min)

- [ ] Stop all validator nodes
  ```bash
  # On each validator
  sudo systemctl stop florad
  ```

- [ ] Verify all stopped
  ```bash
  # Check no florad processes running
  ps aux | grep florad
  ```

### Phase 2: Reset and Initialize (15 min)

- [ ] Reset chain state (each validator)
  ```bash
  florad tendermint unsafe-reset-all
  ```

- [ ] Run genesis script (each validator)
  ```bash
  chmod +x genesis_devnet_766999.sh
  ./genesis_devnet_766999.sh [genesis|guardian|nexus]
  ```

- [ ] Verify gentx created
  ```bash
  ls -la ~/.flora/config/gentx/
  ```

### Phase 3: Coordination (30 min)

- [ ] Collect gentx files (to Flora-Genesis)
  ```bash
  # From Guardian and Nexus to Genesis
  scp ~/.flora/config/gentx/gentx-*.json ubuntu@52.9.17.25:~/.flora/config/gentx/
  ```

- [ ] Add faucet and dev pool accounts (Flora-Genesis only)
  ```bash
  florad genesis add-genesis-account $FAUCET_ADDR 500000000000000000000000000uflora
  florad genesis add-genesis-account $DEVPOOL_ADDR 200000000000000000000000000uflora
  ```

- [ ] Collect genesis transactions (Flora-Genesis only)
  ```bash
  florad genesis collect-gentxs
  ```

- [ ] Update EVM chain ID (Flora-Genesis only)
  ```bash
  cat ~/.flora/config/genesis.json | \
    jq '.app_state.evm.params.chain_config.chain_id = "766999"' \
    > ~/.flora/config/tmp_genesis.json && \
    mv ~/.flora/config/tmp_genesis.json ~/.flora/config/genesis.json
  ```

- [ ] Validate genesis (Flora-Genesis only)
  ```bash
  florad genesis validate-genesis
  ```

- [ ] Calculate SHA256 hash (Flora-Genesis)
  ```bash
  sha256sum ~/.flora/config/genesis.json
  # Record hash: _______________
  ```

### Phase 4: Distribution (15 min)

- [ ] Distribute genesis.json (from Flora-Genesis)
  ```bash
  scp ~/.flora/config/genesis.json ubuntu@50.18.34.12:~/.flora/config/genesis.json
  scp ~/.flora/config/genesis.json ubuntu@204.236.162.240:~/.flora/config/genesis.json
  ```

- [ ] Verify hash matches (all validators)
  ```bash
  # On each validator - must match recorded hash
  sha256sum ~/.flora/config/genesis.json
  ```

### Phase 5: Configuration (15 min)

- [ ] Get node IDs (each validator)
  ```bash
  florad tendermint show-node-id
  # Genesis: _______________
  # Guardian: _______________
  # Nexus: _______________
  ```

- [ ] Update persistent peers (each validator)
  ```bash
  # Edit ~/.flora/config/config.toml
  # persistent_peers = "NODE_ID@IP:26656,..."
  ```

- [ ] Set genesis time (all validators - must match)
  ```bash
  # Update in genesis.json
  # genesis_time: "2025-XX-XXTXX:XX:XXZ"
  ```

### Phase 6: Launch (5 min)

- [ ] Start all validators simultaneously
  ```bash
  # On each validator
  sudo systemctl start florad
  ```

- [ ] Monitor logs (all validators)
  ```bash
  journalctl -u florad -f
  ```

- [ ] Verify blocks producing
  ```bash
  watch -n 1 'curl -s http://52.9.17.25:26657/status | jq .result.sync_info.latest_block_height'
  ```

## ✅ Post-Regenesis Verification

### Immediate Checks (T+5 min)

- [ ] **All nodes producing blocks**
  ```bash
  curl -s http://52.9.17.25:26657/status | jq '.result.sync_info.latest_block_height'
  curl -s http://50.18.34.12:26657/status | jq '.result.sync_info.latest_block_height'
  curl -s http://204.236.162.240:26657/status | jq '.result.sync_info.latest_block_height'
  ```

- [ ] **EVM chain ID correct**
  ```bash
  curl -s -X POST http://52.9.17.25:8545 \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
    | jq -r '.result'
  # Expected: 0xbb3e7
  ```

- [ ] **Peer connections established**
  ```bash
  curl -s http://52.9.17.25:26657/net_info | jq '.result.n_peers'
  # Expected: 2
  ```

- [ ] **Total supply correct**
  ```bash
  curl -s http://52.9.17.25:1317/cosmos/bank/v1beta1/supply/by_denom?denom=uflora \
    | jq -r '.amount.amount'
  # Expected: 1000000000000000000000000000 (1 billion FLORA)
  ```

### Extended Verification (T+30 min)

- [ ] **Validator balances**
  ```bash
  # Check each validator has ~90M FLORA (100M - 10M staked)
  florad query bank balances $VALIDATOR1_ADDR
  florad query bank balances $VALIDATOR2_ADDR
  florad query bank balances $VALIDATOR3_ADDR
  ```

- [ ] **Faucet balance**
  ```bash
  florad query bank balances $FAUCET_ADDR
  # Expected: 500M FLORA
  ```

- [ ] **Dev pool balance**
  ```bash
  florad query bank balances $DEVPOOL_ADDR
  # Expected: 200M FLORA
  ```

- [ ] **Active validators**
  ```bash
  florad query staking validators | jq '.validators | length'
  # Expected: 3
  ```

- [ ] **MetaMask connection test**
  - [ ] Remove old network (chain ID 9000)
  - [ ] Add new network (chain ID 766999)
  - [ ] Verify connection successful
  - [ ] Check for warnings (should be none for Evmos conflict)

### Communication (T+60 min)

- [ ] **Announce completion**
  - [ ] Discord: "Regenesis complete, chain ID now 766999"
  - [ ] Twitter/X: Status update
  - [ ] Update status page: "Operational"

- [ ] **Share new network info**
  - [ ] RPC URL(s)
  - [ ] Chain ID: 766999 (0xbb3e7)
  - [ ] MetaMask add network link
  - [ ] Link to updated documentation

- [ ] **Monitor for user issues**
  - [ ] Watch Discord/support channels
  - [ ] Check for connection problems
  - [ ] Provide help with wallet updates

## 🆘 Rollback Plan

If critical issues occur within first 2 hours:

1. **Stop all validators**
2. **Restore from backup**
   ```bash
   tar -xzf validator-backup-*.tar.gz -C ~/
   tar -xzf chain-data-backup-*.tar.gz -C ~/
   ```
3. **Restart old chain**
4. **Announce rollback and new attempt date**

## 📝 Post-Mortem

After successful regenesis:

- [ ] **Document actual timeline**
  - [ ] Issues encountered: _______________
  - [ ] Resolution time: _______________
  - [ ] Total downtime: _______________

- [ ] **Update runbooks** with lessons learned

- [ ] **Archive genesis file**
  ```bash
  cp ~/.flora/config/genesis.json \
     ~/genesis-devnet-766999-$(date +%Y%m%d).json
  ```

- [ ] **Update monitoring dashboards** with new chain ID

## Sign-off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Lead Validator (Flora-Genesis) | | | |
| Validator 2 (Flora-Guardian) | | | |
| Validator 3 (Flora-Nexus) | | | |
| Chain Core Team | | | |

---

**Note**: This checklist should be reviewed and updated based on any changes to the regenesis plan or new requirements discovered during preparation.
