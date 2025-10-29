#!/bin/bash

# Simple Regenesis Script - Use flora_766999-1 chain ID
# Assumes nodes already have florad binary

set -e

KEY="$HOME/.ssh/esprezzo/norcal-pub.pem"
CHAIN_ID="flora_766999-1"  # This will make EVM use 766999

echo "=== Simple Regenesis with Chain ID: $CHAIN_ID ==="
echo ""

# First, check that the current binary on the node has our fixes
echo "Checking binary version on Genesis node..."
ssh -i "$KEY" ubuntu@52.9.17.25 'florad version'

echo ""
echo "Step 1: Stopping current chain and backing up..."
ssh -i "$KEY" ubuntu@52.9.17.25 'bash -s' << 'EOF'
    pkill florad 2>/dev/null || true
    if [ -d ~/.flora ]; then
        mv ~/.flora ~/.flora.backup.$(date +%Y%m%d-%H%M%S)
    fi
    echo "Genesis node cleaned"
EOF

ssh -i "$KEY" ubuntu@50.18.34.12 'bash -s' << 'EOF'
    pkill florad 2>/dev/null || true
    if [ -d ~/.flora ]; then
        mv ~/.flora ~/.flora.backup.$(date +%Y%m%d-%H%M%S)
    fi
    echo "Guardian node cleaned"
EOF

ssh -i "$KEY" ubuntu@204.236.162.240 'bash -s' << 'EOF'
    pkill florad 2>/dev/null || true
    if [ -d ~/.flora ]; then
        mv ~/.flora ~/.flora.backup.$(date +%Y%m%d-%H%M%S)
    fi
    echo "Nexus node cleaned"
EOF

echo ""
echo "Step 2: Reinitializing with new chain ID..."

# Genesis Node
ssh -i "$KEY" ubuntu@52.9.17.25 "bash -s" << EOF
    florad init Flora-Genesis --chain-id $CHAIN_ID

    # Set denoms
    GENESIS=~/.flora/config/genesis.json
    jq '.app_state.staking.params.bond_denom = "uflora"' "\\\$GENESIS" > "\\\$GENESIS.tmp" && mv "\\\$GENESIS.tmp" "\\\$GENESIS"
    jq '.app_state.mint.params.mint_denom = "uflora"' "\\\$GENESIS" > "\\\$GENESIS.tmp" && mv "\\\$GENESIS.tmp" "\\\$GENESIS"
    jq '.app_state.crisis.constant_fee.denom = "uflora"' "\\\$GENESIS" > "\\\$GENESIS.tmp" && mv "\\\$GENESIS.tmp" "\\\$GENESIS"
    jq '.app_state.evm.params.evm_denom = "uflora"' "\\\$GENESIS" > "\\\$GENESIS.tmp" && mv "\\\$GENESIS.tmp" "\\\$GENESIS"

    # Add accounts and create gentx
    echo -e "y\\n" | florad keys add validator --keyring-backend test
    florad genesis add-genesis-account validator 10000000000000000000000000uflora --keyring-backend test
    florad genesis gentx validator 1000000000000000000000000uflora --chain-id $CHAIN_ID --moniker Flora-Genesis --keyring-backend test
    echo "Genesis initialized"
EOF

# Guardian Node
ssh -i "$KEY" ubuntu@50.18.34.12 "bash -s" << EOF
    florad init Flora-Guardian --chain-id $CHAIN_ID

    # Set denoms
    GENESIS=~/.flora/config/genesis.json
    jq '.app_state.staking.params.bond_denom = "uflora"' "\\\$GENESIS" > "\\\$GENESIS.tmp" && mv "\\\$GENESIS.tmp" "\\\$GENESIS"
    jq '.app_state.mint.params.mint_denom = "uflora"' "\\\$GENESIS" > "\\\$GENESIS.tmp" && mv "\\\$GENESIS.tmp" "\\\$GENESIS"
    jq '.app_state.crisis.constant_fee.denom = "uflora"' "\\\$GENESIS" > "\\\$GENESIS.tmp" && mv "\\\$GENESIS.tmp" "\\\$GENESIS"
    jq '.app_state.evm.params.evm_denom = "uflora"' "\\\$GENESIS" > "\\\$GENESIS.tmp" && mv "\\\$GENESIS.tmp" "\\\$GENESIS"

    echo -e "y\\n" | florad keys add validator --keyring-backend test
    florad genesis add-genesis-account validator 10000000000000000000000000uflora --keyring-backend test
    florad genesis gentx validator 1000000000000000000000000uflora --chain-id $CHAIN_ID --moniker Flora-Guardian --keyring-backend test
    echo "Guardian initialized"
EOF

# Nexus Node
ssh -i "$KEY" ubuntu@204.236.162.240 "bash -s" << EOF
    florad init Flora-Nexus --chain-id $CHAIN_ID

    # Set denoms
    GENESIS=~/.flora/config/genesis.json
    jq '.app_state.staking.params.bond_denom = "uflora"' "\\\$GENESIS" > "\\\$GENESIS.tmp" && mv "\\\$GENESIS.tmp" "\\\$GENESIS"
    jq '.app_state.mint.params.mint_denom = "uflora"' "\\\$GENESIS" > "\\\$GENESIS.tmp" && mv "\\\$GENESIS.tmp" "\\\$GENESIS"
    jq '.app_state.crisis.constant_fee.denom = "uflora"' "\\\$GENESIS" > "\\\$GENESIS.tmp" && mv "\\\$GENESIS.tmp" "\\\$GENESIS"
    jq '.app_state.evm.params.evm_denom = "uflora"' "\\\$GENESIS" > "\\\$GENESIS.tmp" && mv "\\\$GENESIS.tmp" "\\\$GENESIS"

    echo -e "y\\n" | florad keys add validator --keyring-backend test
    florad genesis add-genesis-account validator 10000000000000000000000000uflora --keyring-backend test
    florad genesis gentx validator 1000000000000000000000000uflora --chain-id $CHAIN_ID --moniker Flora-Nexus --keyring-backend test
    echo "Nexus initialized"
EOF

echo ""
echo "=== Initialization Complete ==="
echo "Next: Collect gentxs and start the chain"