#!/usr/bin/env bash
set -euo pipefail

# EIP-155 Polish Regenesis Script (Option A)
# Purpose: Keep Cosmos chain-id stable (flora_7668378-1) and set eip155_block="0"
# Result: eth_chainId returns 0xBB417 without app code changes

CHAIN_ID="flora_7668378-1"    # Cosmos chain-id unchanged
EVM_CHAIN_ID="766999"         # EVM chain id (decimal)
MONIKER="${1:-Flora-Genesis}"

echo "=== EIP-155 Polish Regenesis for $MONIKER ==="

# Clean and init
rm -rf ~/.flora
florad init "$MONIKER" --chain-id "$CHAIN_ID"

# Set all denoms to uflora IMMEDIATELY after init
echo "Setting denoms to uflora..."
jq '.app_state.staking.params.bond_denom = "uflora"' ~/.flora/config/genesis.json > /tmp/g.json && mv /tmp/g.json ~/.flora/config/genesis.json
jq '.app_state.mint.params.mint_denom = "uflora"' ~/.flora/config/genesis.json > /tmp/g.json && mv /tmp/g.json ~/.flora/config/genesis.json
jq '.app_state.crisis.constant_fee.denom = "uflora"' ~/.flora/config/genesis.json > /tmp/g.json && mv /tmp/g.json ~/.flora/config/genesis.json
jq '.app_state.evm.params.evm_denom = "uflora"' ~/.flora/config/genesis.json > /tmp/g.json && mv /tmp/g.json ~/.flora/config/genesis.json

# Set EVM chain config WITH EIP-155 ACTIVATED
echo "Setting EVM chain config with EIP-155..."
jq --arg chainid "$EVM_CHAIN_ID" '.app_state.evm.params.chain_config.chain_id = $chainid' ~/.flora/config/genesis.json > /tmp/g.json && mv /tmp/g.json ~/.flora/config/genesis.json

# SET EIP-155 BLOCK TO "0" - THIS IS THE KEY FIX
jq '.app_state.evm.params.chain_config.eip155_block = "0"' ~/.flora/config/genesis.json > /tmp/g.json && mv /tmp/g.json ~/.flora/config/genesis.json

# Set other EIP blocks for completeness
jq '.app_state.evm.params.chain_config.homestead_block = "0"' ~/.flora/config/genesis.json > /tmp/g.json && mv /tmp/g.json ~/.flora/config/genesis.json
jq '.app_state.evm.params.chain_config.byzantium_block = "0"' ~/.flora/config/genesis.json > /tmp/g.json && mv /tmp/g.json ~/.flora/config/genesis.json
jq '.app_state.evm.params.chain_config.constantinople_block = "0"' ~/.flora/config/genesis.json > /tmp/g.json && mv /tmp/g.json ~/.flora/config/genesis.json
jq '.app_state.evm.params.chain_config.petersburg_block = "0"' ~/.flora/config/genesis.json > /tmp/g.json && mv /tmp/g.json ~/.flora/config/genesis.json
jq '.app_state.evm.params.chain_config.istanbul_block = "0"' ~/.flora/config/genesis.json > /tmp/g.json && mv /tmp/g.json ~/.flora/config/genesis.json
jq '.app_state.evm.params.chain_config.berlin_block = "0"' ~/.flora/config/genesis.json > /tmp/g.json && mv /tmp/g.json ~/.flora/config/genesis.json
jq '.app_state.evm.params.chain_config.london_block = "0"' ~/.flora/config/genesis.json > /tmp/g.json && mv /tmp/g.json ~/.flora/config/genesis.json

# Create/recover validator key
if ! florad keys show validator --keyring-backend test >/dev/null 2>&1; then
    echo "Creating validator key..."
    florad keys add validator --keyring-backend test
else
    echo "Validator key exists"
fi

VALIDATOR_ADDR=$(florad keys show validator -a --keyring-backend test)
echo "Validator address: $VALIDATOR_ADDR"

# Add validator balance (10M FLORA)
florad genesis add-genesis-account "$VALIDATOR_ADDR" 10000000000000000000000000uflora

# If this is the lead node, create system accounts and prepare allocations
if [[ "$MONIKER" == "Flora-Genesis" ]]; then
    echo "Lead node: creating faucet/devpool/reserve keys and adding balances..."
    florad keys add faucet  --keyring-backend test >/dev/null 2>&1 || true
    florad keys add devpool --keyring-backend test >/dev/null 2>&1 || true
    florad keys add reserve --keyring-backend test >/dev/null 2>&1 || true
    FAUCET=$(florad  keys show faucet  -a --keyring-backend test)
    DEVPOOL=$(florad keys show devpool -a --keyring-backend test)
    RESERVE=$(florad keys show reserve -a --keyring-backend test)
    florad genesis add-genesis-account "$FAUCET"  10000000000000000000000000uflora
    florad genesis add-genesis-account "$DEVPOOL" 1000000000000000000000000uflora
    florad genesis add-genesis-account "$RESERVE" 9000000000000000000000000uflora
    echo "Total accounts added: validator + faucet + dev + reserve = 50M components prepared"
fi

# Generate gentx (1M FLORA self-stake)
echo "Generating gentx..."
florad genesis gentx validator 1000000000000000000000000uflora \
  --from validator \
  --keyring-backend test \
  --chain-id "$CHAIN_ID" \
  --moniker "$MONIKER" \
  --commission-rate 0.10 \
  --commission-max-rate 0.20 \
  --commission-max-change-rate 0.01 \
  --min-self-delegation 1

# Verify gentx validity
GENTX_FILE=$(ls ~/.flora/config/gentx/gentx-*.json)
DELEGATOR=$(jq -r '.body.messages[0].delegator_address' "$GENTX_FILE")
DENOM=$(jq -r '.body.messages[0].value.denom' "$GENTX_FILE")

if [[ -z "$DELEGATOR" || "$DELEGATOR" == "null" ]]; then
    echo "ERROR: Empty delegator_address in gentx!"
    exit 1
fi

if [[ "$DENOM" != "uflora" ]]; then
    echo "ERROR: Wrong denom in gentx: $DENOM (expected uflora)"
    exit 1
fi

echo "✅ Gentx valid: delegator=$DELEGATOR, denom=$DENOM"
echo "Gentx file: $GENTX_FILE"

# Show EVM config for verification
echo "=== EVM Chain Config ==="
jq '.app_state.evm.params.chain_config' ~/.flora/config/genesis.json

echo "✅ EIP-155 polish regenesis prepared for $MONIKER"
