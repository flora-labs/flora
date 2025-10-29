# Flora DevNet Documentation

## Overview
Flora DevNet is a development blockchain network for testing and development purposes. This document provides comprehensive instructions for deploying and managing Flora DevNet nodes.

## Quick Start

### Single Node DevNet
```bash
# Build Flora
make install

# Initialize node
florad init mynode --chain-id flora_766999-1

# Start node
florad start
```

### Multi-Node DevNet (3 Validators)
```bash
# Use the test script
./scripts/test_node.sh
```

## Network Configuration

### Chain Parameters
- **Chain ID**: `flora_766999-1`
- **EVM Chain ID**: `766999` (0x74FD37) - Devnet
- **EVM Chain ID (Future)**: `766793` (0xBB349) - Mainnet (reserved)
- **Native Token**: uflora
- **Consensus**: Tendermint BFT
- **Block Time**: ~5 seconds

### Port Configuration
| Service | Port | Description |
|---------|------|-------------|
| P2P | 26656 | Peer-to-peer communication |
| RPC | 26657 | Tendermint RPC |
| gRPC | 9090 | Cosmos gRPC |
| gRPC-Web | 9091 | Cosmos gRPC Web |
| REST | 1317 | Cosmos REST API |
| EVM RPC | 8545 | Ethereum JSON-RPC |
| EVM WS | 8546 | Ethereum WebSocket |
| Prometheus | 26660 | Metrics endpoint |

## Deployment Methods

### Method 1: Local Development Node

1. **Initialize Genesis**
```bash
florad init local-node --chain-id flora_766999-1
```

2. **Configure Genesis**
```bash
# Add genesis account
florad keys add validator --keyring-backend test
florad genesis add-genesis-account validator 1000000000uflora --keyring-backend test

# Create genesis transaction
florad genesis gentx validator 1000000uflora \
  --chain-id flora_766999-1 \
  --keyring-backend test

# Collect genesis transactions
florad genesis collect-gentxs
```

3. **Start Node**
```bash
florad start
```

### Method 2: Docker Deployment

1. **Build Docker Image**
```bash
docker build -t flora:local .
```

2. **Run Container**
```bash
docker run -d \
  --name flora-node \
  -p 26656:26656 \
  -p 26657:26657 \
  -p 1317:1317 \
  -p 8545:8545 \
  -p 9090:9090 \
  -v ~/.flora:/root/.flora \
  flora:local
```

### Method 3: Docker Compose (3 Validators)

1. **Start Network**
```bash
docker-compose up -d
```

2. **Check Status**
```bash
docker-compose ps
docker-compose logs -f
```

3. **Stop Network**
```bash
docker-compose down -v
```

## AWS Deployment

### EC2 Instance Setup

1. **Launch EC2 Instance**
- AMI: Ubuntu 22.04 LTS
- Instance Type: t3.large (minimum)
- Storage: 100GB SSD
- Security Group: Open ports 26656, 26657, 8545

2. **Install Dependencies**
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Go
wget https://go.dev/dl/go1.21.1.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.1.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc

# Install build tools
sudo apt install -y build-essential git
```

3. **Build Flora**
```bash
git clone https://github.com/flora-labs/flora.git
cd flora
make install
```

4. **Configure Systemd Service**
```bash
sudo tee /etc/systemd/system/florad.service > /dev/null <<EOF
[Unit]
Description=Flora Node
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu
ExecStart=/home/ubuntu/go/bin/florad start
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable florad
sudo systemctl start florad
```

## Node Configuration

### app.toml Configuration
```toml
# EVM Configuration
[evm]
tracer = ""
max-tx-gas-wanted = 0

# JSON-RPC Configuration
[json-rpc]
enable = true
address = "0.0.0.0:8545"
ws-address = "0.0.0.0:8546"
api = "eth,net,web3,debug,personal"
gas-cap = 25000000
evm-timeout = "5s"
txfee-cap = 1
filter-cap = 200
feehistory-cap = 100
logs-cap = 10000
block-range-cap = 10000
http-timeout = "30s"
http-idle-timeout = "120s"
allow-unprotected-txs = false
max-open-connections = 0
enable-indexer = false
metrics-address = "0.0.0.0:6065"
```

### config.toml Configuration
```toml
# P2P Configuration
[p2p]
laddr = "tcp://0.0.0.0:26656"
persistent_peers = ""
seeds = ""
max_num_inbound_peers = 40
max_num_outbound_peers = 10

# RPC Configuration
[rpc]
laddr = "tcp://0.0.0.0:26657"
cors_allowed_origins = ["*"]
cors_allowed_methods = ["HEAD", "GET", "POST"]
cors_allowed_headers = ["Origin", "Accept", "Content-Type"]

# Consensus Configuration
[consensus]
timeout_propose = "3s"
timeout_propose_delta = "500ms"
timeout_prevote = "1s"
timeout_prevote_delta = "500ms"
timeout_precommit = "1s"
timeout_precommit_delta = "500ms"
timeout_commit = "5s"
```

## Monitoring

### Check Node Status
```bash
# Node info
florad status

# Check sync status
florad status | jq .SyncInfo

# Get latest block
florad query block

# Check peers
florad tendermint show-node-id
curl -s localhost:26657/net_info | jq .result.peers[].node_info.id
```

### EVM Testing
```bash
# Get chain ID
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  http://localhost:8545

# Get block number
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:8545

# Get gas price
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_gasPrice","params":[],"id":1}' \
  http://localhost:8545
```

## Testnet Seeds

### Current Testnet Validators
```
# Seed Nodes
seeds = "e3e06f1efeeca5daf7c7c0ad6a2216c0cadfa676@52.9.17.25:26656,ebf668f4d1e2b21e895e7889050ebb43364c18b3@50.18.34.12:26656,22a444539995192ada565f118069f11c0069e67e@204.236.162.240:26656"

# Persistent Peers (same as seeds for small networks)
persistent_peers = "e3e06f1efeeca5daf7c7c0ad6a2216c0cadfa676@52.9.17.25:26656,ebf668f4d1e2b21e895e7889050ebb43364c18b3@50.18.34.12:26656,22a444539995192ada565f118069f11c0069e67e@204.236.162.240:26656"
```

## Troubleshooting

### Common Issues

1. **Node Not Syncing**
```bash
# Check peers
curl localhost:26657/net_info

# Restart with seeds
florad start --p2p.seeds "node1_id@ip:26656,node2_id@ip:26656"
```

2. **EVM Not Responding**
```bash
# Check if enabled in app.toml
grep "enable = true" ~/.flora/config/app.toml

# Check JSON-RPC address
grep "address = " ~/.flora/config/app.toml
```

3. **Port Already in Use**
```bash
# Find process using port
sudo lsof -i :26656
sudo lsof -i :8545

# Kill process
sudo kill -9 <PID>
```

4. **Database Corruption**
```bash
# Reset state
florad tendermint unsafe-reset-all

# Or full reset
rm -rf ~/.flora
# Then reinitialize
```

## Security Considerations

### Firewall Rules
```bash
# Allow P2P
sudo ufw allow 26656/tcp

# Allow RPC (only if public)
sudo ufw allow 26657/tcp

# Allow EVM (only if public)
sudo ufw allow 8545/tcp

# Enable firewall
sudo ufw enable
```

### Private Keys
- Never expose validator private keys
- Use hardware security modules for production
- Backup keys securely
- Use separate keys for testing

## Performance Tuning

### System Limits
```bash
# Add to /etc/security/limits.conf
* soft nofile 65535
* hard nofile 65535
```

### Database Backend
```toml
# config.toml
db_backend = "goleveldb"  # or "rocksdb" for better performance
```

### Pruning Configuration
```toml
# app.toml
pruning = "custom"
pruning-keep-recent = "100"
pruning-interval = "10"
```

## Resources

- **GitHub**: https://github.com/flora-labs/flora
- **Discord**: https://discord.flora.network
- **Documentation**: (coming soon) 
