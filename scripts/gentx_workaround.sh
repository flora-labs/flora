#!/usr/bin/env bash
set -euo pipefail

# WORKAROUND for gentx delegator_address bug
# This script creates a proper gentx by directly using the tx command
# instead of the broken genesis gentx command

# Parameters
VALIDATOR_NAME=${1:-validator}
AMOUNT=${2:-1000000000000000000000000uflora}
CHAIN_ID=${3:-flora_7668378-1}
MONIKER=${4:-Flora-Node}
HOME_DIR=${5:-$HOME/.flora}
KEYRING=${6:-test}

echo "Creating gentx workaround for $VALIDATOR_NAME"

# Get validator address
VALIDATOR_ADDR=$(./build/florad keys show $VALIDATOR_NAME -a --keyring-backend $KEYRING --home $HOME_DIR)
if [ -z "$VALIDATOR_ADDR" ]; then
    echo "Error: Validator key $VALIDATOR_NAME not found"
    exit 1
fi
echo "Validator address: $VALIDATOR_ADDR"

# Get validator operator address
VALIDATOR_OP=$(./build/florad keys show $VALIDATOR_NAME --bech val -a --keyring-backend $KEYRING --home $HOME_DIR)
echo "Validator operator: $VALIDATOR_OP"

# Get consensus pubkey from priv_validator_key.json
PRIV_VAL_KEY="$HOME_DIR/config/priv_validator_key.json"
if [ ! -f "$PRIV_VAL_KEY" ]; then
    echo "Error: priv_validator_key.json not found at $PRIV_VAL_KEY"
    exit 1
fi

# Extract the consensus pubkey
CONSENSUS_PUBKEY=$(jq -r '.pub_key.value' "$PRIV_VAL_KEY")
echo "Consensus pubkey: $CONSENSUS_PUBKEY"

# Create the validator JSON
cat > /tmp/create_validator.json <<EOF
{
  "@type": "/cosmos.staking.v1beta1.MsgCreateValidator",
  "description": {
    "moniker": "$MONIKER",
    "identity": "",
    "website": "",
    "security_contact": "",
    "details": ""
  },
  "commission": {
    "rate": "0.100000000000000000",
    "max_rate": "0.200000000000000000",
    "max_change_rate": "0.010000000000000000"
  },
  "min_self_delegation": "1",
  "delegator_address": "$VALIDATOR_ADDR",
  "validator_address": "$VALIDATOR_OP",
  "pubkey": {
    "@type": "/cosmos.crypto.ed25519.PubKey",
    "key": "$CONSENSUS_PUBKEY"
  },
  "value": {
    "denom": "uflora",
    "amount": "${AMOUNT%uflora}"
  }
}
EOF

# Generate the transaction
./build/florad tx staking create-validator \
    --amount="$AMOUNT" \
    --pubkey='{"@type":"/cosmos.crypto.ed25519.PubKey","key":"'$CONSENSUS_PUBKEY'"}' \
    --moniker="$MONIKER" \
    --commission-rate="0.10" \
    --commission-max-rate="0.20" \
    --commission-max-change-rate="0.01" \
    --min-self-delegation="1" \
    --from="$VALIDATOR_NAME" \
    --chain-id="$CHAIN_ID" \
    --keyring-backend="$KEYRING" \
    --home="$HOME_DIR" \
    --generate-only \
    --output-document="/tmp/gentx_unsigned.json"

# Sign the transaction
./build/florad tx sign /tmp/gentx_unsigned.json \
    --from="$VALIDATOR_NAME" \
    --chain-id="$CHAIN_ID" \
    --keyring-backend="$KEYRING" \
    --home="$HOME_DIR" \
    --output-document="/tmp/gentx_signed.json"

# Move to gentx directory
GENTX_DIR="$HOME_DIR/config/gentx"
mkdir -p "$GENTX_DIR"
NODE_ID=$(./build/florad comet show-node-id --home "$HOME_DIR")
cp /tmp/gentx_signed.json "$GENTX_DIR/gentx-${NODE_ID}.json"

echo "Gentx created at: $GENTX_DIR/gentx-${NODE_ID}.json"

# Verify it has delegator_address
jq '.body.messages[0].delegator_address' "$GENTX_DIR/gentx-${NODE_ID}.json"