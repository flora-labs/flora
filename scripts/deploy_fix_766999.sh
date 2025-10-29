#!/bin/bash

# Flora Devnet Regenesis Script - Fix EVM Chain ID to 766999
# This script deploys the fixed binary and performs regenesis with correct chain ID

set -e

# Configuration
KEY="$HOME/.ssh/esprezzo/norcal-pub.pem"
CHAIN_ID="flora_766999-1"  # NEW chain ID for EVM 766999
BINARY_PATH="./build/florad"

# Node IPs
GENESIS_IP="52.9.17.25"
GUARDIAN_IP="50.18.34.12"
NEXUS_IP="204.236.162.240"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Flora Devnet EVM Chain ID Fix Deployment ===${NC}"
echo -e "${YELLOW}Target Chain ID: $CHAIN_ID (EVM: 766999)${NC}"
echo ""

# Check if binary exists
if [ ! -f "$BINARY_PATH" ]; then
    echo -e "${RED}Error: Binary not found at $BINARY_PATH${NC}"
    echo "Please run 'make build' first"
    exit 1
fi

# Check if SSH key exists
if [ ! -f "$KEY" ]; then
    echo -e "${RED}Error: SSH key not found at $KEY${NC}"
    exit 1
fi

echo -e "${GREEN}Step 1: Copying new binary to all nodes...${NC}"
for NODE in $GENESIS_IP $GUARDIAN_IP $NEXUS_IP; do
    echo "  Copying to $NODE..."
    scp -i "$KEY" "$BINARY_PATH" "ubuntu@$NODE:~/florad.new"
done

echo -e "${GREEN}Step 2: Stopping current services and backing up...${NC}"
for NODE in $GENESIS_IP $GUARDIAN_IP $NEXUS_IP; do
    echo "  Processing $NODE..."
    ssh -i "$KEY" "ubuntu@$NODE" 'bash -s' << 'EOF'
        # Stop service
        sudo systemctl stop florad 2>/dev/null || true
        pkill florad 2>/dev/null || true

        # Backup current data
        if [ -d ~/.flora ]; then
            mv ~/.flora ~/.flora.backup.$(date +%Y%m%d-%H%M%S)
        fi

        # Install new binary
        sudo mv ~/florad.new /usr/local/bin/florad
        sudo chmod +x /usr/local/bin/florad

        echo "    Node prepared successfully"
EOF
done

echo -e "${GREEN}Step 3: Initialize Genesis node with new chain ID...${NC}"
ssh -i "$KEY" "ubuntu@$GENESIS_IP" 'bash -s' << EOF
    set -e

    # Initialize with NEW chain ID for proper EVM 766999
    florad init Flora-Genesis --chain-id $CHAIN_ID

    # Set denoms BEFORE creating gentx
    GENESIS=~/.flora/config/genesis.json
    jq '.app_state.staking.params.bond_denom = "uflora"' "\$GENESIS" > "\$GENESIS.tmp" && mv "\$GENESIS.tmp" "\$GENESIS"
    jq '.app_state.mint.params.mint_denom = "uflora"' "\$GENESIS" > "\$GENESIS.tmp" && mv "\$GENESIS.tmp" "\$GENESIS"
    jq '.app_state.crisis.constant_fee.denom = "uflora"' "\$GENESIS" > "\$GENESIS.tmp" && mv "\$GENESIS.tmp" "\$GENESIS"
    jq '.app_state.evm.params.evm_denom = "uflora"' "\$GENESIS" > "\$GENESIS.tmp" && mv "\$GENESIS.tmp" "\$GENESIS"

    # Create validator key and account
    echo -e "y\n" | florad keys add validator --keyring-backend test
    VALIDATOR=\$(florad keys show validator -a --keyring-backend test)

    # Add genesis account
    florad genesis add-genesis-account \$VALIDATOR 10000000000000000000000000uflora --keyring-backend test

    # Create gentx
    florad genesis gentx validator 1000000000000000000000000uflora \
        --chain-id $CHAIN_ID \
        --moniker Flora-Genesis \
        --keyring-backend test

    echo "Genesis node initialized"
EOF

echo -e "${GREEN}Step 4: Initialize Guardian node...${NC}"
ssh -i "$KEY" "ubuntu@$GUARDIAN_IP" 'bash -s' << EOF
    set -e

    florad init Flora-Guardian --chain-id $CHAIN_ID

    # Set denoms
    GENESIS=~/.flora/config/genesis.json
    jq '.app_state.staking.params.bond_denom = "uflora"' "\$GENESIS" > "\$GENESIS.tmp" && mv "\$GENESIS.tmp" "\$GENESIS"
    jq '.app_state.mint.params.mint_denom = "uflora"' "\$GENESIS" > "\$GENESIS.tmp" && mv "\$GENESIS.tmp" "\$GENESIS"
    jq '.app_state.crisis.constant_fee.denom = "uflora"' "\$GENESIS" > "\$GENESIS.tmp" && mv "\$GENESIS.tmp" "\$GENESIS"
    jq '.app_state.evm.params.evm_denom = "uflora"' "\$GENESIS" > "\$GENESIS.tmp" && mv "\$GENESIS.tmp" "\$GENESIS"

    # Create validator
    echo -e "y\n" | florad keys add validator --keyring-backend test
    florad genesis add-genesis-account validator 10000000000000000000000000uflora --keyring-backend test
    florad genesis gentx validator 1000000000000000000000000uflora \
        --chain-id $CHAIN_ID \
        --moniker Flora-Guardian \
        --keyring-backend test

    echo "Guardian node initialized"
EOF

echo -e "${GREEN}Step 5: Initialize Nexus node...${NC}"
ssh -i "$KEY" "ubuntu@$NEXUS_IP" 'bash -s' << EOF
    set -e

    florad init Flora-Nexus --chain-id $CHAIN_ID

    # Set denoms
    GENESIS=~/.flora/config/genesis.json
    jq '.app_state.staking.params.bond_denom = "uflora"' "\$GENESIS" > "\$GENESIS.tmp" && mv "\$GENESIS.tmp" "\$GENESIS"
    jq '.app_state.mint.params.mint_denom = "uflora"' "\$GENESIS" > "\$GENESIS.tmp" && mv "\$GENESIS.tmp" "\$GENESIS"
    jq '.app_state.crisis.constant_fee.denom = "uflora"' "\$GENESIS" > "\$GENESIS.tmp" && mv "\$GENESIS.tmp" "\$GENESIS"
    jq '.app_state.evm.params.evm_denom = "uflora"' "\$GENESIS" > "\$GENESIS.tmp" && mv "\$GENESIS.tmp" "\$GENESIS"

    # Create validator
    echo -e "y\n" | florad keys add validator --keyring-backend test
    florad genesis add-genesis-account validator 10000000000000000000000000uflora --keyring-backend test
    florad genesis gentx validator 1000000000000000000000000uflora \
        --chain-id $CHAIN_ID \
        --moniker Flora-Nexus \
        --keyring-backend test

    echo "Nexus node initialized"
EOF

echo -e "${GREEN}Step 6: Collecting gentx files...${NC}"

# Copy gentx files to Genesis node
echo "  Copying Guardian gentx..."
ssh -i "$KEY" "ubuntu@$GUARDIAN_IP" 'cat ~/.flora/config/gentx/gentx-*.json' > /tmp/gentx-guardian.json
scp -i "$KEY" /tmp/gentx-guardian.json "ubuntu@$GENESIS_IP:/tmp/"

echo "  Copying Nexus gentx..."
ssh -i "$KEY" "ubuntu@$NEXUS_IP" 'cat ~/.flora/config/gentx/gentx-*.json' > /tmp/gentx-nexus.json
scp -i "$KEY" /tmp/gentx-nexus.json "ubuntu@$GENESIS_IP:/tmp/"

# Collect on Genesis node
ssh -i "$KEY" "ubuntu@$GENESIS_IP" 'bash -s' << 'EOF'
    set -e

    # Copy gentx files
    cp /tmp/gentx-guardian.json ~/.flora/config/gentx/
    cp /tmp/gentx-nexus.json ~/.flora/config/gentx/

    # Add other validator accounts
    GUARDIAN_ADDR="flora1m9jlex28cyrzu7ka0y9phmq2maeztc2t86uv6c"
    NEXUS_ADDR="flora1rvqehz2j43rx0zteeemc3r6x63saaqmhmpltpp"

    florad genesis add-genesis-account $GUARDIAN_ADDR 10000000000000000000000000uflora --keyring-backend test
    florad genesis add-genesis-account $NEXUS_ADDR 10000000000000000000000000uflora --keyring-backend test

    # Add special accounts
    FAUCET="flora1mgzls4ssrnw8ant466qurvydjrh907p9eyd9vm"
    DEVPOOL="flora1w42u8uarwzydzewz4u6j8z706crgj5jm78zwlw"
    RESERVE="flora147xcqczhk40hq9p58pleljalaxzhtfh7pzkdd6"

    florad genesis add-genesis-account $FAUCET 10000000000000000000000000uflora --keyring-backend test
    florad genesis add-genesis-account $DEVPOOL 1000000000000000000000000uflora --keyring-backend test
    florad genesis add-genesis-account $RESERVE 9000000000000000000000000uflora --keyring-backend test

    # CRITICAL: Collect gentxs
    florad genesis collect-gentxs

    # Validate
    florad genesis validate

    echo "Genesis file complete"
EOF

echo -e "${GREEN}Step 7: Distributing genesis file...${NC}"

# Get genesis from Genesis node and distribute
ssh -i "$KEY" "ubuntu@$GENESIS_IP" 'cat ~/.flora/config/genesis.json' > /tmp/genesis.json

for NODE in $GUARDIAN_IP $NEXUS_IP; do
    echo "  Copying to $NODE..."
    scp -i "$KEY" /tmp/genesis.json "ubuntu@$NODE:~/.flora/config/genesis.json"
done

echo -e "${GREEN}Step 8: Getting node IDs and setting up peers...${NC}"

# Get node IDs
GENESIS_ID=$(ssh -i "$KEY" "ubuntu@$GENESIS_IP" 'florad tendermint show-node-id')
GUARDIAN_ID=$(ssh -i "$KEY" "ubuntu@$GUARDIAN_IP" 'florad tendermint show-node-id')
NEXUS_ID=$(ssh -i "$KEY" "ubuntu@$NEXUS_IP" 'florad tendermint show-node-id')

echo "  Genesis ID: $GENESIS_ID"
echo "  Guardian ID: $GUARDIAN_ID"
echo "  Nexus ID: $NEXUS_ID"

# Build peer strings
GENESIS_PEER="${GENESIS_ID}@${GENESIS_IP}:26656"
GUARDIAN_PEER="${GUARDIAN_ID}@${GUARDIAN_IP}:26656"
NEXUS_PEER="${NEXUS_ID}@${NEXUS_IP}:26656"

# Configure peers on each node
echo "  Configuring Genesis peers..."
ssh -i "$KEY" "ubuntu@$GENESIS_IP" "sed -i 's/persistent_peers = \"\"/persistent_peers = \"$GUARDIAN_PEER,$NEXUS_PEER\"/' ~/.flora/config/config.toml"

echo "  Configuring Guardian peers..."
ssh -i "$KEY" "ubuntu@$GUARDIAN_IP" "sed -i 's/persistent_peers = \"\"/persistent_peers = \"$GENESIS_PEER,$NEXUS_PEER\"/' ~/.flora/config/config.toml"

echo "  Configuring Nexus peers..."
ssh -i "$KEY" "ubuntu@$NEXUS_IP" "sed -i 's/persistent_peers = \"\"/persistent_peers = \"$GENESIS_PEER,$GUARDIAN_PEER\"/' ~/.flora/config/config.toml"

echo -e "${GREEN}Step 9: Configuring APIs and starting nodes...${NC}"

for NODE in $GENESIS_IP $GUARDIAN_IP $NEXUS_IP; do
    echo "  Configuring and starting $NODE..."
    ssh -i "$KEY" "ubuntu@$NODE" 'bash -s' << 'EOF'
        set -e

        # Enable APIs
        APP=~/.flora/config/app.toml
        sed -i '/^\[api\]/,/^\[/{
            s/^enable = .*/enable = true/
            s/^address = .*/address = "tcp:\/\/0.0.0.0:1317"/
        }' $APP
        sed -i '/^\[api\]/a\enabled-unsafe-cors = true' $APP 2>/dev/null || true

        # Enable JSON-RPC
        sed -i '/^\[json-rpc\]/,/^\[/{
            s/^enable = .*/enable = true/
            s/^address = .*/address = "0.0.0.0:8545"/
        }' $APP

        # Enable CORS in config.toml
        CONFIG=~/.flora/config/config.toml
        sed -i 's/cors_allowed_origins = \[\]/cors_allowed_origins = \["*"\]/' $CONFIG

        # Start the node
        nohup florad start > ~/flora.log 2>&1 &

        echo "    Node started"
EOF
    sleep 3
done

echo -e "${GREEN}Step 10: Waiting for chain to start...${NC}"
sleep 10

echo -e "${GREEN}Step 11: Verification...${NC}"

# Check block height
echo -e "${YELLOW}Checking block production:${NC}"
for NODE in $GENESIS_IP $GUARDIAN_IP $NEXUS_IP; do
    HEIGHT=$(curl -s "http://$NODE:26657/status" | jq -r '.result.sync_info.latest_block_height' 2>/dev/null || echo "0")
    echo "  $NODE: Block height $HEIGHT"
done

# Check EVM chain ID
echo -e "${YELLOW}Checking EVM Chain ID (should be 0xbb417 = 766999):${NC}"
for NODE in $GENESIS_IP $GUARDIAN_IP $NEXUS_IP; do
    CHAIN_ID=$(curl -s -X POST "http://$NODE:8545" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' 2>/dev/null | jq -r '.result' || echo "N/A")

    if [ "$CHAIN_ID" = "0xbb417" ]; then
        echo -e "  $NODE: ${GREEN}✓ Chain ID: $CHAIN_ID (766999)${NC}"
    else
        echo -e "  $NODE: ${RED}✗ Chain ID: $CHAIN_ID (Expected 0xbb417)${NC}"
    fi
done

# Check validators
echo -e "${YELLOW}Checking validators:${NC}"
VALIDATORS=$(curl -s "http://$GENESIS_IP:1317/cosmos/staking/v1beta1/validators" 2>/dev/null | jq -r '.validators | length' || echo "0")
echo "  Active validators: $VALIDATORS"

echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""
echo "Access points:"
echo "  RPC: http://$GENESIS_IP:26657"
echo "  REST API: http://$GENESIS_IP:1317"
echo "  EVM JSON-RPC: http://$GENESIS_IP:8545"
echo ""
echo "Check logs:"
echo "  ssh -i $KEY ubuntu@$GENESIS_IP 'tail -f ~/flora.log'"
echo ""
echo "Expected EVM Chain ID: 766999 (0xbb417)"
echo "Actual Cosmos Chain ID: $CHAIN_ID"