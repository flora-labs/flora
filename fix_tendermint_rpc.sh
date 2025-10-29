#!/bin/bash

# Fix Tendermint RPC to bind to all interfaces (0.0.0.0) instead of localhost
# This enables external access to port 26657

set -e

# Configuration
KEY="$HOME/.ssh/esprezzo/norcal-pub.pem"
NODES=("52.9.17.25" "50.18.34.12" "204.236.162.240")
NODE_NAMES=("Genesis" "Guardian" "Nexus")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Fixing Tendermint RPC Configuration ===${NC}"
echo -e "${YELLOW}This will enable external access to port 26657${NC}"
echo ""

# Check if SSH key exists
if [ ! -f "$KEY" ]; then
    echo -e "${RED}Error: SSH key not found at $KEY${NC}"
    exit 1
fi

# Fix configuration on each node
for i in "${!NODES[@]}"; do
    NODE="${NODES[$i]}"
    NAME="${NODE_NAMES[$i]}"

    echo -e "${GREEN}Processing $NAME node ($NODE)...${NC}"

    ssh -i "$KEY" "ubuntu@$NODE" 'bash -s' << 'EOF'
        CONFIG="$HOME/.flora/config/config.toml"

        # Check current configuration
        echo "  Current RPC configuration:"
        grep "^laddr = " $CONFIG | grep -A0 "section\|rpc" || grep "^laddr = " $CONFIG | head -1

        # Update laddr to bind to all interfaces
        echo "  Updating configuration..."
        sed -i 's/laddr = "tcp:\/\/127.0.0.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/' $CONFIG
        sed -i 's/laddr = "tcp:\/\/localhost:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/' $CONFIG

        # Verify the change
        echo "  New RPC configuration:"
        grep "^laddr = " $CONFIG | head -1

        # Restart the service
        echo "  Restarting florad service..."
        sudo systemctl restart florad || {
            echo "  Systemctl restart failed, trying direct restart..."
            pkill florad 2>/dev/null || true
            sleep 2
            nohup florad start > ~/florad.log 2>&1 &
        }

        sleep 3

        # Test if RPC is now accessible
        echo "  Testing RPC endpoint..."
        curl -s -m 2 http://localhost:26657/status > /dev/null && echo "  ✓ RPC is responding locally" || echo "  ✗ RPC not responding"
EOF

    echo ""
done

echo -e "${GREEN}Waiting 10 seconds for services to stabilize...${NC}"
sleep 10

echo -e "${GREEN}Testing external RPC access:${NC}"
for i in "${!NODES[@]}"; do
    NODE="${NODES[$i]}"
    NAME="${NODE_NAMES[$i]}"

    echo -n "  $NAME ($NODE): "
    if curl -s -m 2 "http://$NODE:26657/status" | jq -r '.result.node_info.network' 2>/dev/null; then
        echo " ✅ RPC accessible"
    else
        echo " ❌ RPC not accessible externally"
    fi
done

echo ""
echo -e "${GREEN}Testing other services:${NC}"

# Test all critical services
for NODE in "${NODES[@]}"; do
    echo -e "${YELLOW}Node $NODE:${NC}"

    # EVM RPC
    echo -n "  EVM RPC (8545): "
    curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
        "http://$NODE:8545" | jq -r '.result' 2>/dev/null && echo "✅" || echo "❌"

    # Tendermint RPC
    echo -n "  Tendermint RPC (26657): "
    curl -s "http://$NODE:26657/status" > /dev/null 2>&1 && echo "✅" || echo "❌"

    # REST API
    echo -n "  REST API (1317): "
    curl -s "http://$NODE:1317/cosmos/base/tendermint/v1beta1/node_info" > /dev/null 2>&1 && echo "✅" || echo "❌"

    # gRPC (if enabled)
    echo -n "  gRPC (9090): "
    nc -zv -w2 $NODE 9090 > /dev/null 2>&1 && echo "✅" || echo "❌ (may be disabled)"

    echo ""
done

echo -e "${GREEN}=== Configuration Complete ===${NC}"
echo ""
echo "Summary of endpoints:"
echo "  Tendermint RPC: http://<node-ip>:26657"
echo "  EVM JSON-RPC: http://<node-ip>:8545"
echo "  REST API: http://<node-ip>:1317"
echo "  gRPC: <node-ip>:9090"
echo ""
echo "ALB health checks for flora-rpc-nodes should now pass!"