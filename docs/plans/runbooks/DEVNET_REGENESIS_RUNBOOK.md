# Runbook: Flora Devnet Regenesis (EVM Chain ID 766999 / 0xBB417)

Status: ready
Owner: chain-core
Last Updated: 2025-10-16

This runbook executes the devnet regenesis to move EVM chain ID to 766999 (0xBB417), using the role-based helper script and a 50,000,000 FLORA total supply.

## Pre‑Flight (Lead + All Validators)

- Confirm SSH access to all nodes.
- Ensure same florad binary on all nodes.
- Decide genesis time if coordinating a timed start.

## Create Devnet Accounts (Lead node only)

```bash
cd ~/flora
./scripts/create_genesis_accounts.sh
# Produces: genesis_accounts.env (FAUCET_ADDR, DEVPOOL_ADDR)
```

## Validator Steps (on each validator: Genesis, Guardian, Nexus)

```bash
# Replace <MONIKER> per node: Flora-Genesis / Flora-Guardian / Flora-Nexus
ROLE=validator ./scripts/quick_regenesis_766999.sh <MONIKER>

# Pre-collect sanity (on each validator)
./scripts/diagnose_gentx_and_genesis.sh
# Ensure delegator_address in each gentx is NON-EMPTY and value.denom == uflora before sending to Genesis.
# If delegator_address is empty: STOP and re-run gentx with correct flags:
#   florad genesis gentx validator 1000000000000000000000000uflora \
#     --from validator --keyring-backend test --chain-id flora_7668378-1 \
#     --moniker <MONIKER> --commission-rate 0.10 --commission-max-rate 0.20 \
#     --commission-max-change-rate 0.01 --min-self-delegation 1

# Send gentx to the lead node (Genesis)
scp ~/.flora/config/gentx/gentx-*.json ubuntu@52.9.17.25:~/.flora/config/gentx/
```

## Lead Steps (on Genesis)

```bash
cd ~
# If FAUCET_ADDR/DEVPOOL_ADDR not exported, the script will source ./genesis_accounts.env
ROLE=lead ./scripts/quick_regenesis_766999.sh Flora-Genesis

# If any gentx has an empty delegator address, STOP and fix gentx generation (see Issue 0005).

# Output includes final genesis SHA256
```

## Distribute Final genesis.json

```bash
scp ~/.flora/config/genesis.json ubuntu@50.18.34.12:~/.flora/config/genesis.json
scp ~/.flora/config/genesis.json ubuntu@204.236.162.240:~/.flora/config/genesis.json
```

## Configure Persistent Peers (all validators)

```bash
NODE_ID=$(florad tendermint show-node-id)
# Edit ~/.flora/config/config.toml:
# persistent_peers = "<GENESIS_ID>@52.9.17.25:26656,<GUARDIAN_ID>@50.18.34.12:26656,<NEXUS_ID>@204.236.162.240:26656"
```

## Start Validators (coordinated)

```bash
sudo systemctl start florad
journalctl -u florad -f
```

## Verification

```bash
# Blocks
curl -s 52.9.17.25:26657/status | jq '.result.sync_info.latest_block_height'

# EVM chain ID (expect 0xBB417)
curl -s -X POST 52.9.17.25:8545 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' | jq -r '.result'

# Peers (expect 2 on each validator)
curl -s 52.9.17.25:26657/net_info | jq '.result.n_peers'

# Total supply (expect 50,000,000 FLORA)
florad query bank total | jq -r '.supply[] | select(.denom=="uflora").amount'
```

## Rollback

```bash
sudo systemctl stop florad
# Restore backups of ~/.flora and prior binary if taken, then start service
```

## Notes

- Chain IDs: Cosmos flora_7668378-1 (unchanged), EVM 766999 (0xBB417)
- Total Supply: 50,000,000 FLORA (10M per validator, 10M faucet, 1M dev pool, 9M reserve)
- Scripts: scripts/quick_regenesis_766999.sh, scripts/create_genesis_accounts.sh
