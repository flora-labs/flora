# Handoff Document - Flora Devnet Regenesis (BLOCKED)

## Current State - October 16, 2025
**Status**: ❌ BLOCKED - gentx delegator_address bug preventing validator set creation
**Chain**: Not producing blocks (height = 0)
**Explorer**: Offline (waiting for chain to start)

## SSH Access (CRITICAL - DO NOT LOSE)
```bash
KEY=~/.ssh/esprezzo/norcal-pub.pem
ssh -i $KEY ubuntu@52.9.17.25      # Genesis node
ssh -i $KEY ubuntu@50.18.34.12     # Guardian node
ssh -i $KEY ubuntu@204.236.162.240  # Nexus node
```

## What Was Attempted
1. **Goal**: Implement Option A - Keep Cosmos chain-id `flora_7668378-1`, enable EIP-155 at genesis so eth_chainId returns 0xBB417
2. **Scripts Updated**:
   - `scripts/quick_regenesis_766999.sh` - Sets denoms pre-gentx, enables EIP-155, validates gentx
   - `scripts/enable_jsonrpc_rest.sh` - Enables JSON-RPC and REST
   - `scripts/verify_eip155_polish.sh` - Verification helper
3. **Execution**: Attempted full regenesis with correct SSH key

## Critical Blocker Found
### The Problem
The current `florad` binary has a bug in `genesis gentx` command:
- **Bug**: Creates gentx with empty `delegator_address` field
- **Impact**: Validator set cannot be initialized, chain won't start
- **Evidence**: All gentx files show `"delegator_address": ""`

### What Fails
1. Empty delegator_address → collect-gentxs fails
2. If manually repaired → signature invalid, InitGenesis fails
3. If re-signed → validator set still empty after InitGenesis

## Two Solutions Available

### Option A1: Rebuild Binary (RECOMMENDED)
```bash
# Find last known good commit
git log --grep="gentx" --oneline

# Rebuild at good commit
make clean && make build

# Deploy to nodes and re-run
```

### Option A2: Genesis Surgery (Faster)
- Skip gentx entirely
- Directly inject validators into genesis JSON
- Script this to be deterministic
- Proceed with start

## Current Genesis Configuration (Ready)
- **Cosmos chain-id**: `flora_7668378-1` (unchanged)
- **EVM config**:
  - `chain_id`: "766999"
  - `eip155_block`: "0"
- **Allocations** (50M total):
  - 3 validators × 10M
  - Faucet: 10M
  - Dev pool: 1M
  - Reserve: 9M

## Success Criteria
- [ ] eth_chainId returns 0xBB417
- [ ] All 3 validators producing blocks
- [ ] Total supply = 50M FLORA
- [ ] Explorer shows "Connected"

## Critical Files
- `docs/REGENESIS_STATUS_REPORT.md` - Full status with Section 17 (Critical Issue)
- `docs/plans/issues/0005-devnet-regenesis-blockers.md` - Detailed failure analysis
- `docs/plans/runbooks/DEVNET_EIP155_POLISH_RUNBOOK.md` - Step-by-step runbook
- `scripts/quick_regenesis_766999.sh` - Regenesis script (ready to use)

## Common Pitfalls to Avoid
1. **DO NOT** set gRPC address to 1317 (causes crash)
   - Correct: `[grpc] address = "0.0.0.0:9090"`
   - REST API: `[api] address = "tcp://0.0.0.0:1317"`

2. **DO NOT** forget to set denoms BEFORE gentx
   - Must set bond_denom, mint_denom, crisis fee, evm_denom to "uflora"

3. **DO NOT** change ALB configuration
   - It's already configured correctly
   - Explorer just needs the chain to start

## Next Steps for You
1. Choose Option A1 or A2
2. If A1: Find good commit, rebuild, deploy
3. If A2: Create genesis surgery script
4. Run the polish regenesis
5. Verify all success criteria

## Questions Answered
- **Why is explorer offline?** Chain isn't producing blocks yet
- **Why doesn't eth_chainId work?** Chain must start first
- **Do we need ALB changes?** NO - already configured
- **What about ConPort?** Deprecated - using Lux now

Good luck! The scripts and docs are ready - just need to fix the gentx bug.