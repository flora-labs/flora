#!/usr/bin/env bash
set -euo pipefail

# Remote driver for Option A (EIP-155 polish regenesis) across 3 nodes.
# Requirements on your workstation: ssh/scp access to all nodes as $SSH_USER (default: ubuntu).
# Usage (example):
#   SSH_USER=ubuntu LEAD=52.9.17.25 GUARDIAN=50.18.34.12 NEXUS=204.236.162.240 \
#   bash scripts/remote_eip155_polish_driver.sh

: "${LEAD?Set LEAD=<lead_ip>}"
: "${GUARDIAN?Set GUARDIAN=<guardian_ip>}"
: "${NEXUS?Set NEXUS=<nexus_ip>}"
SSH_USER=${SSH_USER:-ubuntu}
SCRIPT_LOCAL="scripts/quick_regenesis_766999.sh"

echo "== Checking SSH access =="
for host in "$LEAD" "$GUARDIAN" "$NEXUS"; do
  echo "SSH -> $host"
  ssh -o BatchMode=yes -o ConnectTimeout=8 "$SSH_USER@$host" 'echo ok'
done

echo "== Ensuring jq present and florad available =="
for host in "$LEAD" "$GUARDIAN" "$NEXUS"; do
  ssh "$SSH_USER@$host" 'jq --version >/dev/null 2>&1 || (sudo apt-get update -y && sudo apt-get install -y jq); command -v florad >/dev/null || { echo "florad not found"; exit 1; }'
done

echo "== Pushing helper script to all nodes =="
for host in "$LEAD" "$GUARDIAN" "$NEXUS"; do
  scp "$SCRIPT_LOCAL" "$SSH_USER@$host:~/quick_regenesis_766999.sh"
  ssh "$SSH_USER@$host" 'chmod +x ~/quick_regenesis_766999.sh'
done

echo "== Preparing validators (Guardian, Nexus) =="
ssh "$SSH_USER@$GUARDIAN" 'printf "YES\n" | ROLE=validator bash ~/quick_regenesis_766999.sh "Flora-Guardian"'
ssh "$SSH_USER@$NEXUS"    'printf "YES\n" | ROLE=validator bash ~/quick_regenesis_766999.sh "Flora-Nexus"'

echo "== Collecting validator gentx to local =="
rm -f gentx-guardian.json gentx-nexus.json
scp "$SSH_USER@$GUARDIAN:~/.flora/config/gentx/gentx-*.json" gentx-guardian.json
scp "$SSH_USER@$NEXUS:~/.flora/config/gentx/gentx-*.json"    gentx-nexus.json

echo "== Placing gentx on lead and running lead flow =="
ssh "$SSH_USER@$LEAD" 'mkdir -p ~/.flora/config/gentx'
scp gentx-guardian.json gentx-nexus.json "$SSH_USER@$LEAD:~/.flora/config/gentx/"
ssh "$SSH_USER@$LEAD" 'printf "YES\n" | ROLE=lead bash ~/quick_regenesis_766999.sh "Flora-Genesis"'

echo "== Distributing genesis.json from lead to peers =="
scp "$SSH_USER@$LEAD:~/.flora/config/genesis.json" genesis.json
scp genesis.json "$SSH_USER@$GUARDIAN:~/.flora/config/genesis.json"
scp genesis.json "$SSH_USER@$NEXUS:~/.flora/config/genesis.json"

echo "== Configuring persistent_peers =="
GID=$(ssh "$SSH_USER@$LEAD"     'florad comet show-node-id')
UID=$(ssh "$SSH_USER@$GUARDIAN" 'florad comet show-node-id')
NID=$(ssh "$SSH_USER@$NEXUS"    'florad comet show-node-id')

# Update config.toml on each node
ssh "$SSH_USER@$LEAD"     "sed -i 's/^persistent_peers = .*/persistent_peers = \"'$UID'@$GUARDIAN:26656,'$NID'@$NEXUS:26656\"/' ~/.flora/config/config.toml"
ssh "$SSH_USER@$GUARDIAN" "sed -i 's/^persistent_peers = .*/persistent_peers = \"'$GID'@$LEAD:26656,'$NID'@$NEXUS:26656\"/' ~/.flora/config/config.toml"
ssh "$SSH_USER@$NEXUS"    "sed -i 's/^persistent_peers = .*/persistent_peers = \"'$GID'@$LEAD:26656,'$UID'@$GUARDIAN:26656\"/' ~/.flora/config/config.toml"

echo "== Starting validators (lead, then others) =="
ssh "$SSH_USER@$LEAD" 'sudo systemctl start florad && sleep 4 && systemctl is-active --quiet florad && echo started'
ssh "$SSH_USER@$GUARDIAN" 'sudo systemctl start florad && systemctl is-active --quiet florad && echo started'
ssh "$SSH_USER@$NEXUS"    'sudo systemctl start florad && systemctl is-active --quiet florad && echo started'

echo "== Verifying block height, EVM params, JSON-RPC chainId =="
for host in "$LEAD" "$GUARDIAN" "$NEXUS"; do
  echo "--- $host ---"
  ssh "$SSH_USER@$host" 'echo -n height=; curl -s localhost:26657/status | jq -r .result.sync_info.latest_block_height; \
                          echo -n peers=;  curl -s localhost:26657/net_info | jq -r .result.n_peers; \
                          echo -n evm_chain_id=; florad query evm params -o json | jq -r .params.chain_config.chain_id; \
                          echo -n eth_chainId=; curl -s -X POST localhost:8545 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' | jq -r .result'
done

echo "== REST via ALB =="
curl -s https://devnet-api.flora.network/cosmos/base/tendermint/v1beta1/node_info | jq -r .default_node_info.network || true

echo "✅ EIP-155 polish complete. Expect eth_chainId=0xBB417 and network=flora_7668378-1"

