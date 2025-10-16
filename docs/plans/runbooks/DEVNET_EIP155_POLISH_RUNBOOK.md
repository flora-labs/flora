# Runbook: Devnet EIP‑155 “Polish” Regenesis (Cosmos ID unchanged)

Status: ready
Owner: chain-core
Last Updated: 2025-10-16 (UTC)

Purpose
- Make wallets return eth_chainId = 0xBB417 (766999) over JSON‑RPC by enabling EIP‑155 at genesis, while keeping the Cosmos chain‑id unchanged (flora_7668378-1).
- Bring the explorer to “Connected” by ensuring REST (1317) is enabled and reachable (no ALB changes required).
- Maintain a clean, no‑code, predictable devnet process.

Scope
- Validators: 3 (Genesis 52.9.17.25; Guardian 50.18.34.12; Nexus 204.236.162.240)
- Cosmos chain‑id: flora_7668378-1 (unchanged)
- EVM chain id: 766999 (0xBB417)
- Maintenance window: ~20–30 minutes (devnet)

Summary of changes in this polish
- Set EVM EIP‑155 activation at genesis: app_state.evm.params.chain_config.eip155_block = "0" (and chain_id = "766999").
- Keep denoms = uflora everywhere (staking/mint/crisis/evm).
- Mint allocations in genesis: 10M per validator, 10M faucet, 1M dev pool, 9M reserve → total 50M.
- Create gentx via stock CLI (no JSON edits).

Roles
- Lead validator: Genesis (52.9.17.25)
- Validators: Guardian (50.18.34.12), Nexus (204.236.162.240)

Pre‑flight
1) SSH access verified to all nodes with sudo.
2) florad binary identical across nodes (/usr/local/bin/florad).
3) Confirm ALB/API endpoint remains https://devnet-api.flora.network (no change).

T‑0: Stop and wipe (devnet)
```bash
for ip in 52.9.17.25 50.18.34.12 204.236.162.240; do
  ssh ubuntu@$ip 'sudo systemctl stop florad || true; rm -rf ~/.flora'
 done
```

T‑1: Initialize nodes with Cosmos chain‑id (unchanged)
```bash
ssh ubuntu@52.9.17.25  'florad init Flora-Genesis  --chain-id flora_7668378-1'
ssh ubuntu@50.18.34.12  'florad init Flora-Guardian --chain-id flora_7668378-1'
ssh ubuntu@204.236.162.240 'florad init Flora-Nexus   --chain-id flora_7668378-1'
```

T‑2: Set denoms before any gentx (all nodes)
```bash
for ip in 52.9.17.25 50.18.34.12 204.236.162.240; do
  ssh ubuntu@$ip 'G=$HOME/.flora/config/genesis.json; \
    jq ".app_state.staking.params.bond_denom=\"uflora\"" "$G" > $G.tmp && mv $G.tmp $G; \
    jq ".app_state.mint.params.mint_denom=\"uflora\"" "$G" > $G.tmp && mv $G.tmp $G; \
    jq ".app_state.crisis.constant_fee.denom=\"uflora\"" "$G" > $G.tmp && mv $G.tmp $G; \
    jq ".app_state.evm.params.evm_denom=\"uflora\"" "$G" > $G.tmp && mv $G.tmp $G'
 done
```

T‑3: Prepare keys and addresses (lead)
```bash
ssh ubuntu@52.9.17.25 '
  florad keys add faucet   --keyring-backend test >/dev/null 2>&1 || true
  florad keys add devpool  --keyring-backend test >/dev/null 2>&1 || true
  florad keys add reserve  --keyring-backend test >/dev/null 2>&1 || true
  FAUCET=$(florad  keys show faucet  -a --keyring-backend test)
  DEVPOOL=$(florad keys show devpool -a --keyring-backend test)
  RESERVE=$(florad keys show reserve -a --keyring-backend test)
  echo faucet=$FAUCET devpool=$DEVPOOL reserve=$RESERVE
'
```

T‑4: Set EVM chain config (lead only)
```bash
ssh ubuntu@52.9.17.25 '
  G=$HOME/.flora/config/genesis.json
  jq ".app_state.evm.params.chain_config.chain_id=\"766999\"" "$G" > $G.tmp && mv $G.tmp $G
  jq ".app_state.evm.params.chain_config.eip155_block=\"0\""      "$G" > $G.tmp && mv $G.tmp $G
'
```

T‑5: Mint genesis allocations (lead only)
```bash
ssh ubuntu@52.9.17.25 '
  LEAD=$(florad keys show validator -a --keyring-backend test)
  # Fill these with Guardian/Nexus delegator addresses
  GUARD=<<GUARD_ADDR>>
  NEXUS=<<NEXUS_ADDR>>
  # 10M to each validator
  florad genesis add-genesis-account "$LEAD"  10000000000000000000000000uflora || true
  florad genesis add-genesis-account "$GUARD" 10000000000000000000000000uflora || true
  florad genesis add-genesis-account "$NEXUS" 10000000000000000000000000uflora || true
  # Faucet 10M, Dev pool 1M, Reserve 9M
  FAUCET=$(florad keys show faucet  -a --keyring-backend test)
  DEVPOOL=$(florad keys show devpool -a --keyring-backend test)
  RESERVE=$(florad keys show reserve -a --keyring-backend test)
  florad genesis add-genesis-account "$FAUCET"  10000000000000000000000000uflora || true
  florad genesis add-genesis-account "$DEVPOOL" 1000000000000000000000000uflora  || true
  florad genesis add-genesis-account "$RESERVE" 9000000000000000000000000uflora  || true
'
```

T‑6: Create validator gentx (stock CLI; all nodes)
```bash
for ip in 52.9.17.25 50.18.34.12 204.236.162.240; do
  ssh ubuntu@$ip '
    florad keys add validator --keyring-backend test --output json >/dev/null 2>&1 || true
    ADDR=$(florad keys show validator -a --keyring-backend test)
    florad genesis add-genesis-account "$ADDR" 10000000000000000000000000uflora || true
    rm -f ~/.flora/config/gentx/*.json || true
    florad genesis gentx validator 1000000000000000000000000uflora \
      --chain-id flora_7668378-1 --moniker $(hostname) \
      --commission-rate 0.10 --commission-max-rate 0.20 --commission-max-change-rate 0.01 \
      --min-self-delegation 1 --keyring-backend test --from validator >/dev/null
    jq -r '.body.messages[0].delegator_address, .body.messages[0].value.denom' ~/.flora/config/gentx/gentx-*.json
  '
 done
```
Expect: non‑empty delegator_address (flora1…) and denom uflora for all three gentx files.

T‑7: Collect gentx and lock genesis (lead)
```bash
# Copy gentx from Guardian/Nexus to lead ~/.flora/config/gentx/
# Then on lead:
ssh ubuntu@52.9.17.25 '
  florad genesis collect-gentxs
  florad genesis validate
  sha256sum ~/.flora/config/genesis.json | awk '{print $1}'
'
```
Record the SHA256; all nodes must match.

T‑8: Distribute genesis and configure peers
```bash
for ip in 50.18.34.12 204.236.162.240; do
  scp ubuntu@52.9.17.25:~/.flora/config/genesis.json ubuntu@$ip:~/.flora/config/genesis.json
  ssh ubuntu@$ip 'sha256sum ~/.flora/config/genesis.json | awk '\''{print $1}'\'''
 done
# persistent_peers
GID=$(ssh ubuntu@52.9.17.25  'florad comet show-node-id')
UID=$(ssh ubuntu@50.18.34.12  'florad comet show-node-id')
NID=$(ssh ubuntu@204.236.162.240 'florad comet show-node-id')
ssh ubuntu@52.9.17.25  "sed -i 's/^persistent_peers = .*/persistent_peers = \"'$UID'@50.18.34.12:26656,'$NID'@204.236.162.240:26656\"/' ~/.flora/config/config.toml"
ssh ubuntu@50.18.34.12  "sed -i 's/^persistent_peers = .*/persistent_peers = \"'$GID'@52.9.17.25:26656,'$NID'@204.236.162.240:26656\"/' ~/.flora/config/config.toml"
ssh ubuntu@204.236.162.240 "sed -i 's/^persistent_peers = .*/persistent_peers = \"'$GID'@52.9.17.25:26656,'$UID'@50.18.34.12:26656\"/' ~/.flora/config/config.toml"
```

T‑9: Enable JSON‑RPC/REST (nodes)
```bash
for ip in 52.9.17.25 50.18.34.12 204.236.162.240; do
  ssh ubuntu@$ip '
    APP=$HOME/.flora/config/app.toml
    # JSON-RPC
    sed -i "s/^enable *= *.*/enable = true/" "$APP" || true
    sed -i "s#^address *= *\".*\"#address = \"0.0.0.0:8545\"#" "$APP" || true
    sed -i "s#^ws-address *= *\".*\"#ws-address = \"0.0.0.0:8546\"#" "$APP" || true
    grep -q '^api = ' "$APP" || echo 'api = "eth,net,web3,debug,personal,txpool"' >> "$APP"
    # REST API (Cosmos API)
    # Depending on the app.toml layout, REST is usually under an API section and listens on tcp://0.0.0.0:1317.
    # DO NOT set the gRPC block (9090) to 1317 — that will crash with: "invalid grpc address tcp://0.0.0.0:1317".
    # Ensure [grpc] address remains 0.0.0.0:9090 if present.
    sed -i "s/^enable *= *.*/enable = true/" "$APP" || true
    sed -i "s#^address *= *\".*\"#address = \"tcp://0.0.0.0:1317\"#" "$APP" || true
    sed -i "s/^enabled-unsafe-cors *= *.*/enabled-unsafe-cors = true/" "$APP" || true
  '
 done
```

T‑10: Start validators (lead → others)
```bash
ssh ubuntu@52.9.17.25  'sudo systemctl start florad'
sleep 4
for ip in 50.18.34.12 204.236.162.240; do ssh ubuntu@$ip 'sudo systemctl start florad'; done
```

Verification
```bash
# Tendermint
for ip in 52.9.17.25 50.18.34.12 204.236.162.240; do
  echo $ip; ssh ubuntu@$ip 'curl -s localhost:26657/status | jq -r .result.sync_info.latest_block_height; curl -s localhost:26657/net_info | jq -r .result.n_peers'
 done
# On-chain EVM params
for ip in 52.9.17.25 50.18.34.12 204.236.162.240; do
  echo $ip; ssh ubuntu@$ip 'florad query evm params -o json | jq -r .params.chain_config.chain_id'
 done
# JSON-RPC chainId (should be 0xBB417)
for ip in 52.9.17.25 50.18.34.12 204.236.162.240; do
  echo $ip; ssh ubuntu@$ip "curl -s -X POST localhost:8545 -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_chainId\",\"params\":[],\"id\":1}' | jq -r .result"
 done
# REST over ALB
curl -s https://devnet-api.flora.network/cosmos/base/tendermint/v1beta1/node_info | jq -r .default_node_info.network
```

Explorer notes (stateless client)
- No ALB changes are required. If the UI still shows Offline after nodes are healthy, clear CDN/browser cache.

Risks & Rollback (devnet)
- If a validator shows a different genesis hash, re‑push lead genesis.json to that node and restart; ensure peers are configured.
- If JSON‑RPC returns 0x75029a, verify eip155_block="0" is present in genesis and that the node restarted with the new genesis.

Automation helpers (optional)
- scripts/quick_regenesis_766999.sh: role‑aware helper that sets uflora denoms pre‑gentx, enables EIP‑155 at genesis (eip155_block="0"), prepares allocations, and validates genesis. Use `ROLE=validator` on peers and `ROLE=lead` on the Genesis node.
- scripts/enable_jsonrpc_rest.sh: toggles JSON‑RPC and REST in app.toml for the local node.
- scripts/verify_eip155_polish.sh: prints local/remote block height, peer count, on‑chain EVM chain_id, and eth_chainId.
- scripts/remote_eip155_polish_driver.sh: orchestrates the full polish across all three nodes from your workstation (push scripts, run validator prep, gather gentx, run lead, distribute genesis, set peers, start, verify). Example:
  ```bash
  SSH_USER=ubuntu \
  LEAD=52.9.17.25 GUARDIAN=50.18.34.12 NEXUS=204.236.162.240 \
  bash scripts/remote_eip155_polish_driver.sh
  ```

Troubleshooting — gentx at genesis
- Symptom A: gentx JSON has `delegator_address: ""`. Fix: ensure `--from validator --keyring-backend test` and set all denoms=uflora BEFORE running gentx. If still empty, it is a CLI bug in this build.
- Symptom B: after manually repairing `delegator_address`, node panics at InitGenesis with `signature verification failed`. Fix: each node must re‑sign its own gentx file after any JSON body edits, then the lead should collect again.
- Symptom C: InitGenesis fails with `validator set is empty` even after collect‑gentxs. Likely a binary signing/encoding incompatibility at genesis for this build.

Two paths to resolve (pick one)
- A1: Rebuild `florad` to a revision where `genesis gentx` emits valid `delegator_address` and genesis verification passes; re‑run this runbook.
- A2: Bypass gentx and inject validators + self‑delegations directly into genesis (scriptable), then validate and proceed. Keep allocations identical to the plan.
