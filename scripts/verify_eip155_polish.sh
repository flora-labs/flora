#!/usr/bin/env bash
set -euo pipefail

# Verify EIP-155 polish on a node or set of nodes.
# Usage:
#   Local only:   scripts/verify_eip155_polish.sh
#   Over SSH:     HOSTS="52.9.17.25 50.18.34.12" scripts/verify_eip155_polish.sh

HOSTS=${HOSTS:-}

run_local() {
  echo "-- Tendermint --"
  curl -s localhost:26657/status | jq -r .result.sync_info.latest_block_height
  curl -s localhost:26657/net_info | jq -r .result.n_peers
  echo "-- EVM params (chain_config.chain_id) --"
  florad query evm params -o json | jq -r .params.chain_config.chain_id
  echo "-- JSON-RPC eth_chainId --"
  curl -s -X POST localhost:8545 -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' | jq -r .result
}

if [ -z "$HOSTS" ]; then
  echo "Local verification"
  run_local
else
  for ip in $HOSTS; do
    echo "$ip"
    ssh "ubuntu@$ip" 'bash -s' <<'EOF'
set -euo pipefail
echo "-- Tendermint --"
curl -s localhost:26657/status | jq -r .result.sync_info.latest_block_height
curl -s localhost:26657/net_info | jq -r .result.n_peers
echo "-- EVM params (chain_config.chain_id) --"
florad query evm params -o json | jq -r .params.chain_config.chain_id
echo "-- JSON-RPC eth_chainId --"
curl -s -X POST localhost:8545 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' | jq -r .result
EOF
  done
fi

echo "-- REST via ALB --"
curl -s https://devnet-api.flora.network/cosmos/base/tendermint/v1beta1/node_info | jq -r .default_node_info.network

