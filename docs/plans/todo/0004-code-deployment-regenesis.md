# Code Deployment Plan for Devnet Regenesis

**Status**: approved  
**Owner**: chain-core  
**Created**: 2025-10-15  
**Related**: 0001-runbook-evm-chainid-renumbering-regenesis.md, 0003-devnet-genesis-regenesis-plan.md

## Summary

Complete code deployment plan to build, test, and distribute the Flora binary to all three validator nodes for the devnet regenesis with chain ID 766999.

## Prerequisites

- SSH access to all three validator nodes
- SSH key: `~/.ssh/esprezzo/norcal-pub.pem`
- Git repository: Up to date with master branch
- Local build environment with Go 1.21+

## Node Information

| Node | IP | SSH Command |
|------|-----|-------------|
| Flora-Genesis | 52.9.17.25 | `ssh -i ~/.ssh/esprezzo/norcal-pub.pem ubuntu@52.9.17.25` |
| Flora-Guardian | 50.18.34.12 | `ssh -i ~/.ssh/esprezzo/norcal-pub.pem ubuntu@50.18.34.12` |
| Flora-Nexus | 204.236.162.240 | `ssh -i ~/.ssh/esprezzo/norcal-pub.pem ubuntu@204.236.162.240` |

## Deployment Strategy

### Option 1: Build Locally, Deploy to All Nodes (Recommended)

**Pros**: Guaranteed same binary, faster deployment  
**Cons**: Requires local cross-compilation or matching build environment

### Option 2: Build on Each Node

**Pros**: Simple, no binary transfer needed  
**Cons**: Longer deployment time, potential version mismatches

### Option 3: Build on Lead Node, Copy to Others

**Pros**: Balance of speed and simplicity  
**Cons**: Requires storage on lead node

**Recommended**: Option 1 (build locally, deploy to all)

## Step-by-Step Deployment

### Phase 1: Local Preparation

#### 1.1 Update Local Repository

```bash
# On your local machine
cd /Users/alan/Projects/_FLORA/flora-workspace/chain_build/flora

# Pull latest changes
git checkout master
git pull origin master

# Verify you're on the right commit
git log -1
```

#### 1.2 Build Binary Locally

```bash
# Clean previous builds
make clean

# Build the binary
make build

# Verify build
./build/florad version
# Should show current version

# Test binary locally
./build/florad init test-node --chain-id flora_7668378-1 --home /tmp/test-flora
rm -rf /tmp/test-flora
```

#### 1.3 Create Deployment Package

```bash
# Create deployment directory
mkdir -p deployment/binaries
mkdir -p deployment/scripts

# Copy binary
cp build/florad deployment/binaries/florad

# Copy regenesis script
cp scripts/quick_regenesis_766999.sh deployment/scripts/

# Create version file
echo "Build Date: $(date)" > deployment/VERSION
echo "Git Commit: $(git rev-parse HEAD)" >> deployment/VERSION
echo "Git Branch: $(git branch --show-current)" >> deployment/VERSION
echo "Chain ID (Cosmos): flora_7668378-1" >> deployment/VERSION
echo "Chain ID (EVM): 766999 (0xBB417)" >> deployment/VERSION

# Create tarball for easy transfer
cd deployment
tar -czf flora-deployment-$(date +%Y%m%d-%H%M%S).tar.gz binaries/ scripts/ VERSION
cd ..

echo "Deployment package created: deployment/flora-deployment-*.tar.gz"
```

### Phase 2: Pre-Deployment Checks

#### 2.1 Verify All Nodes Are Accessible

```bash
#!/bin/bash
# check_nodes.sh

NODES=(
  "52.9.17.25"
  "50.18.34.12"
  "204.236.162.240"
)

SSH_KEY="~/.ssh/esprezzo/norcal-pub.pem"

echo "Checking node accessibility..."
for node in "${NODES[@]}"; do
  echo -n "Testing $node... "
  if ssh -i $SSH_KEY -o ConnectTimeout=5 ubuntu@$node "echo OK" 2>/dev/null; then
    echo "✅"
  else
    echo "❌ FAILED"
    exit 1
  fi
done

echo "All nodes accessible!"
```

#### 2.2 Backup Current State

```bash
#!/bin/bash
# backup_nodes.sh

NODES=(
  "52.9.17.25:Flora-Genesis"
  "50.18.34.12:Flora-Guardian"
  "204.236.162.240:Flora-Nexus"
)

SSH_KEY="~/.ssh/esprezzo/norcal-pub.pem"
BACKUP_DATE=$(date +%Y%m%d-%H%M%S)

for node_info in "${NODES[@]}"; do
  IFS=: read -r ip name <<< "$node_info"
  echo "Backing up $name ($ip)..."
  
  ssh -i $SSH_KEY ubuntu@$ip << 'ENDSSH'
    # Create backup directory
    mkdir -p ~/backups
    BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
    
    # Stop florad
    sudo systemctl stop florad
    
    # Backup data directory
    tar -czf ~/backups/flora-data-$BACKUP_DATE.tar.gz ~/.flora/
    
    # Backup current binary
    cp $(which florad) ~/backups/florad-$BACKUP_DATE
    
    echo "✅ Backup created: ~/backups/flora-data-$BACKUP_DATE.tar.gz"
ENDSSH
done

echo "All nodes backed up!"
```

### Phase 3: Binary Deployment

#### 3.1 Deploy Binary to All Nodes

```bash
#!/bin/bash
# deploy_binary.sh

NODES=(
  "52.9.17.25:Flora-Genesis"
  "50.18.34.12:Flora-Guardian"
  "204.236.162.240:Flora-Nexus"
)

SSH_KEY="~/.ssh/esprezzo/norcal-pub.pem"
DEPLOYMENT_TAR=$(ls -t deployment/flora-deployment-*.tar.gz | head -1)

if [ ! -f "$DEPLOYMENT_TAR" ]; then
  echo "❌ Deployment package not found!"
  exit 1
fi

echo "Deploying: $DEPLOYMENT_TAR"

for node_info in "${NODES[@]}"; do
  IFS=: read -r ip name <<< "$node_info"
  echo ""
  echo "═══════════════════════════════════════"
  echo "Deploying to $name ($ip)"
  echo "═══════════════════════════════════════"
  
  # 1. Upload deployment package
  echo "📤 Uploading deployment package..."
  scp -i $SSH_KEY $DEPLOYMENT_TAR ubuntu@$ip:~/
  
  # 2. Extract and install
  echo "📦 Extracting and installing..."
  ssh -i $SSH_KEY ubuntu@$ip << 'ENDSSH'
    # Extract deployment package
    cd ~
    tar -xzf flora-deployment-*.tar.gz
    
    # Stop florad
    sudo systemctl stop florad
    sleep 2
    
    # Install new binary
    sudo cp ~/binaries/florad /usr/local/bin/florad
    sudo chmod +x /usr/local/bin/florad
    
    # Verify installation
    /usr/local/bin/florad version
    
    # Make regenesis script executable
    chmod +x ~/scripts/quick_regenesis_766999.sh
    
    echo "✅ Binary deployed successfully"
ENDSSH
  
  if [ $? -eq 0 ]; then
    echo "✅ $name deployment complete"
  else
    echo "❌ $name deployment FAILED"
    exit 1
  fi
done

echo ""
echo "═══════════════════════════════════════"
echo "✅ All nodes deployed successfully!"
echo "═══════════════════════════════════════"
```

#### 3.2 Verify Binary Installation

```bash
#!/bin/bash
# verify_deployment.sh

NODES=(
  "52.9.17.25:Flora-Genesis"
  "50.18.34.12:Flora-Guardian"
  "204.236.162.240:Flora-Nexus"
)

SSH_KEY="~/.ssh/esprezzo/norcal-pub.pem"

echo "Verifying binary deployment..."
echo ""

for node_info in "${NODES[@]}"; do
  IFS=: read -r ip name <<< "$node_info"
  echo "Checking $name ($ip)..."
  
  VERSION=$(ssh -i $SSH_KEY ubuntu@$ip "florad version 2>&1")
  BINARY_PATH=$(ssh -i $SSH_KEY ubuntu@$ip "which florad")
  BINARY_SHA=$(ssh -i $SSH_KEY ubuntu@$ip "sha256sum $(which florad) | awk '{print \$1}'")
  
  echo "  Version: $VERSION"
  echo "  Path: $BINARY_PATH"
  echo "  SHA256: $BINARY_SHA"
  echo ""
done
```

### Phase 4: Coordinated Regenesis

#### 4.1 Run Regenesis on Each Node

**Node 1: Flora-Genesis (Lead Node)**

```bash
# SSH to Flora-Genesis
ssh -i ~/.ssh/esprezzo/norcal-pub.pem ubuntu@52.9.17.25

# Run regenesis script
cd ~
./scripts/quick_regenesis_766999.sh Flora-Genesis

# Wait for completion, save validator key
# Copy gentx file for collection
```

**Node 2 & 3: Flora-Guardian, Flora-Nexus**

```bash
# On each node, run:
cd ~
./scripts/quick_regenesis_766999.sh <MONIKER>

# Copy gentx files to lead node
# Example from Flora-Guardian:
scp -i ~/.ssh/esprezzo/norcal-pub.pem \
  ~/.flora/config/gentx/gentx-*.json \
  ubuntu@52.9.17.25:~/.flora/config/gentx/
```

#### 4.2 Collect Genesis on Lead Node

```bash
# On Flora-Genesis (52.9.17.25)

# Add faucet and dev pool accounts
florad genesis add-genesis-account flora1faucet... 500000000000000000000000000uflora
florad genesis add-genesis-account flora1devpool... 200000000000000000000000000uflora

# Collect all gentx files
florad genesis collect-gentxs

# Validate genesis
  florad genesis validate

# Calculate hash
sha256sum ~/.flora/config/genesis.json
```

#### 4.3 Distribute Genesis to All Nodes

```bash
# From Flora-Genesis, copy to other nodes
scp -i ~/.ssh/esprezzo/norcal-pub.pem \
  ~/.flora/config/genesis.json \
  ubuntu@50.18.34.12:~/.flora/config/genesis.json

scp -i ~/.ssh/esprezzo/norcal-pub.pem \
  ~/.flora/config/genesis.json \
  ubuntu@204.236.162.240:~/.flora/config/genesis.json
```

#### 4.4 Verify Genesis Hash

```bash
# On ALL nodes, run:
sha256sum ~/.flora/config/genesis.json

# All hashes MUST match!
```

### Phase 5: Network Start

#### 5.1 Configure Persistent Peers

```bash
# On each node, get node ID:
florad tendermint show-node-id

# Update config.toml on each node with peers
# Edit ~/.flora/config/config.toml
# Update the persistent_peers line
```

#### 5.2 Start All Nodes

```bash
# Start in order: Genesis → Guardian → Nexus
# With ~10 second delay between each

# On Flora-Genesis:
sudo systemctl start florad
sleep 10

# On Flora-Guardian:
sudo systemctl start florad
sleep 10

# On Flora-Nexus:
sudo systemctl start florad
```

#### 5.3 Monitor Startup

```bash
# On each node:
journalctl -u florad -f

# Check status:
florad status | jq '.SyncInfo'

# Verify EVM chain ID:
curl -s -X POST http://localhost:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  | jq -r '.result'
  # Expected: 0xBB417
```

## Alternative: Simplified Deployment Script

For those who want a single script to do everything:

```bash
#!/bin/bash
# full_deployment.sh - Complete deployment automation

set -e

NODES=(
  "52.9.17.25:Flora-Genesis"
  "50.18.34.12:Flora-Guardian"
  "204.236.162.240:Flora-Nexus"
)

SSH_KEY="~/.ssh/esprezzo/norcal-pub.pem"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║        Flora Devnet Regenesis - Full Deployment                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Build locally
echo "Step 1: Building binary..."
make clean && make build
echo "✅ Build complete"

# Step 2: Create deployment package
echo "Step 2: Creating deployment package..."
mkdir -p deployment/binaries deployment/scripts
cp build/florad deployment/binaries/
cp scripts/quick_regenesis_766999.sh deployment/scripts/
cd deployment && tar -czf ../flora-deploy.tar.gz * && cd ..
echo "✅ Package created"

# Step 3: Deploy to all nodes
echo "Step 3: Deploying to all nodes..."
for node_info in "${NODES[@]}"; do
  IFS=: read -r ip name <<< "$node_info"
  echo "Deploying to $name..."
  
  scp -i $SSH_KEY flora-deploy.tar.gz ubuntu@$ip:~/
  ssh -i $SSH_KEY ubuntu@$ip << 'ENDSSH'
    tar -xzf flora-deploy.tar.gz
    sudo systemctl stop florad
    sudo cp binaries/florad /usr/local/bin/florad
    sudo chmod +x /usr/local/bin/florad
    chmod +x scripts/quick_regenesis_766999.sh
    echo "Deployed: $(florad version)"
ENDSSH
  
  echo "✅ $name complete"
done

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              Deployment Complete!                               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "1. SSH to each node and run: ./scripts/quick_regenesis_766999.sh <MONIKER>"
echo "2. Collect gentx files on lead node"
echo "3. Distribute final genesis.json to all nodes"
echo "4. Start nodes in order"
```

## Rollback Procedure

If deployment fails:

```bash
# On each node:
sudo systemctl stop florad

# Restore old binary
sudo cp ~/backups/florad-<TIMESTAMP> /usr/local/bin/florad

# Restore old data
rm -rf ~/.flora
tar -xzf ~/backups/flora-data-<TIMESTAMP>.tar.gz -C ~/

# Restart
sudo systemctl start florad
```

## Post-Deployment Verification

```bash
#!/bin/bash
# verify_all.sh

NODES=("52.9.17.25" "50.18.34.12" "204.236.162.240")
SSH_KEY="~/.ssh/esprezzo/norcal-pub.pem"

for ip in "${NODES[@]}"; do
  echo "Verifying $ip..."
  
  # Check florad is running
  ssh -i $SSH_KEY ubuntu@$ip "systemctl status florad | grep Active"
  
  # Check block height
  ssh -i $SSH_KEY ubuntu@$ip "curl -s localhost:26657/status | jq '.result.sync_info.latest_block_height'"
  
  # Check EVM chain ID
  ssh -i $SSH_KEY ubuntu@$ip "curl -s -X POST localhost:8545 -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_chainId\",\"params\":[],\"id\":1}' | jq -r '.result'"
  
  echo "---"
done
```

## Timeline

| Phase | Duration | Notes |
|-------|----------|-------|
| Build & Package | 10 min | Local build |
| Deploy Binaries | 15 min | Upload to 3 nodes |
| Backup Old State | 10 min | Safety measure |
| Regenesis (per node) | 5 min | 15 min total for 3 nodes |
| Genesis Collection | 15 min | Lead node coordination |
| Network Start | 10 min | Coordinated start |
| **Total** | **75 min** | ~1.25 hours |

## Checklist

Pre-Deployment:
- [ ] Local repository up to date
- [ ] Binary built and tested locally
- [ ] SSH access to all nodes verified
- [ ] Deployment package created

Deployment:
- [ ] Binaries deployed to all nodes
- [ ] Binary versions match on all nodes
- [ ] Old state backed up on all nodes

Regenesis:
- [ ] Regenesis completed on all nodes
- [ ] Gentx files collected
- [ ] Genesis.json distributed
- [ ] Genesis hash verified on all nodes

Launch:
- [ ] Persistent peers configured
- [ ] Nodes started in order
- [ ] All nodes producing blocks
- [ ] EVM chain ID verified as 766999
- [ ] Peer connections established

## Support

If issues occur:
- Check logs: `journalctl -u florad -f`
- Verify binary: `florad version`
- Check connectivity: `curl localhost:26657/status`
- Rollback if needed using backup procedure

## References

- `scripts/quick_regenesis_766999.sh` - Automated regenesis script
- `docs/plans/todo/0003-devnet-genesis-regenesis-plan.md` - Genesis plan details
- `docs/plans/todo/0001-runbook-evm-chainid-renumbering-regenesis.md` - Regenesis runbook
