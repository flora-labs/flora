#!/usr/bin/env bash
set -euo pipefail

# Matched IDs Regenesis Script
# Purpose: Use same ID (766999) for both Cosmos network ID and EVM chain ID
# This ensures eth_chainId returns 0xBB417 without code changes
#
# How it works:
# - Cosmos chain ID format: {identifier}_{EIP155}-{version}
# - The number after _ becomes the network ID
# - eth_chainId RPC returns this network ID
# - By using flora_766999-1, we get network ID = 766999 = 0xBB417

CHAIN_ID="flora_766999-1"  # Network ID will be 766999
EVM_CHAIN_ID="766999"       # EVM chain ID matches network ID
MONIKER="${1:-Flora-Genesis}"

echo "=== Matched IDs Regenesis for $MONIKER ==="
echo "Cosmos Chain ID: $CHAIN_ID"
echo "Network ID (extracted): 766999"
echo "EVM Chain ID: $EVM_CHAIN_ID (0xBB417)"
echo "Result: eth_chainId will return 0xBB417"
echo ""

# Clean and init
echo "Step 1: Clean and initialize..."
rm -rf ~/.flora
florad init "$MONIKER" --chain-id "$CHAIN_ID"

# Set all denoms to uflora IMMEDIATELY after init
echo "Step 2: Setting all denoms to uflora..."
jq '.app_state.staking.params.bond_denom = "uflora"' ~/.flora/config/genesis.json > /tmp/g.json && mv /tmp/g.json ~/.flora/config/genesis.json
jq '.app_state.mint.params.mint_denom = "uflora"' ~/.flora/config/genesis.json > /tmp/g.json && mv /tmp/g.json ~/.flora/config/genesis.json
jq '.app_state.crisis.constant_fee.denom = "uflora"' ~/.flora/config/genesis.json > /tmp/g.json && mv /tmp/g.json ~/.flora/config/genesis.json
jq '.app_state.evm.params.evm_denom = "uflora"' ~/.flora/config/genesis.json > /tmp/g.json && mv /tmp/g.json ~/.flora/config/genesis.json

# Set EVM chain config WITH EIP-155 ACTIVATED
echo "Step 3: Setting EVM chain config with EIP-155..."
jq --arg chainid "$EVM_CHAIN_ID" '.app_state.evm.params.chain_config.chain_id = $chainid' ~/.flora/config/genesis.json > /tmp/g.json && mv /tmp/g.json ~/.flora/config/genesis.json

# SET EIP-155 BLOCK TO "0" - Ensures EIP-155 is active from genesis
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
echo "Step 4: Setting up validator key..."
if ! florad keys show validator --keyring-backend test >/dev/null 2>&1; then
    echo "Creating validator key..."
    florad keys add validator --keyring-backend test
else
    echo "Validator key exists"
fi

VALIDATOR_ADDR=$(florad keys show validator -a --keyring-backend test)
echo "Validator address: $VALIDATOR_ADDR"

# Add validator balance (10M FLORA)
echo "Step 5: Adding validator balance (10M FLORA)..."
florad genesis add-genesis-account "$VALIDATOR_ADDR" 10000000000000000000000000uflora

# If this is the lead node, add other accounts
if [[ "$MONIKER" == "Flora-Genesis" ]]; then
    echo "Step 6: Lead node - adding other accounts..."

    # Guardian validator (10M)
    florad genesis add-genesis-account flora1cqjy4vmunclynyvwd6s4dk79e5w0ne5glm8w3t 10000000000000000000000000uflora

    # Nexus validator (10M)
    florad genesis add-genesis-account flora15f9kuxqzflkfafh05nczfajvjqn5d7rgfexqrz 10000000000000000000000000uflora

    # Faucet account (10M)
    florad genesis add-genesis-account flora1faucet000000000000000000000000000faucet 10000000000000000000000000uflora

    # Dev pool (1M)
    florad genesis add-genesis-account flora1devpool00000000000000000000000000devpol 1000000000000000000000000uflora

    # Reserve account (9M) - Reaches exactly 50M total
    florad genesis add-genesis-account flora1reserve00000000000000000000000000reserve 9000000000000000000000000uflora

    echo "Total: 50M FLORA (3x10M validators + 10M faucet + 1M dev + 9M reserve)"
fi

# Generate gentx (1M FLORA self-stake)
echo "Step 7: Generating gentx with 1M FLORA stake..."
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
echo "Step 8: Verifying gentx..."
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

# Show chain IDs for verification
echo ""
echo "=== Final Verification ==="
echo "Cosmos Chain ID: $(jq -r '.chain_id' ~/.flora/config/genesis.json)"
echo "EVM Chain ID: $(jq -r '.app_state.evm.params.chain_config.chain_id' ~/.flora/config/genesis.json)"
echo "EIP-155 Block: $(jq -r '.app_state.evm.params.chain_config.eip155_block' ~/.flora/config/genesis.json)"
echo ""
echo "✅ Matched IDs regenesis prepared for $MONIKER"
echo ""
echo "Next steps:"
echo "1. Copy gentx files from validators to lead node"
echo "2. Run 'florad genesis collect-gentxs' on lead node"
echo "3. Distribute final genesis.json to all nodes"
echo "4. Start all nodes"
echo "5. Verify eth_chainId returns 0xBB417"