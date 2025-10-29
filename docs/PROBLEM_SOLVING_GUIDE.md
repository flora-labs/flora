# Flora Network Problem-Solving Guide
**Last Updated**: October 16, 2025
**Purpose**: Complete troubleshooting guide for Flora network launches and relaunches

## Table of Contents
1. [Common Issues & Solutions](#common-issues--solutions)
2. [Validator Issues](#validator-issues)
3. [API & Explorer Issues](#api--explorer-issues)
4. [Network Configuration](#network-configuration)
5. [Quick Reference Commands](#quick-reference-commands)

---

## Common Issues & Solutions

### Issue 1: "validator set is empty after InitGenesis"
**Symptoms**:
- Error message: `error on replay: validator set is empty after InitGenesis`
- Chain won't start
- No validators in genesis

**Root Cause**:
- Gentx files not collected into genesis
- NOT caused by empty delegator_address (that's normal!)

**Solution**:
```bash
# The critical missing step
florad genesis collect-gentxs

# Verify collection
cat ~/.flora/config/genesis.json | jq '.app_state.genutil.gen_txs | length'
# Should show number of validators (e.g., 3)

# Validate genesis
florad genesis validate
```

**Prevention**: Always run `collect-gentxs` after creating all gentx files

---

### Issue 2: Empty delegator_address in gentx
**Symptoms**:
- gentx files have `"delegator_address": ""`
- Worry that this is a bug

**Reality**: THIS IS NORMAL COSMOS SDK BEHAVIOR!
- The chain has always worked this way
- Empty delegator_address defaults to validator's account
- DO NOT try to "fix" this

**What NOT to do**:
```bash
# DO NOT run repair scripts
# DO NOT manually edit gentx files
# DO NOT add delegator_address manually
```

**Correct approach**:
```bash
# Just use gentx as-is with empty delegator_address
florad genesis gentx validator 1000000000000000000000000uflora \
  --chain-id flora_766999-1 \
  --moniker [moniker] \
  --keyring-backend test
# Leave it as is - it's correct!
```

---

### Issue 3: eth_chainId returns wrong value
**Symptoms**:
- `eth_chainId` returns 0x2328 (9000) instead of configured value
- MetaMask warnings about chain ID

**Root Cause**:
- EIP-155 not activated at genesis block
- Evmos module quirk

**Solution**:
```bash
# Set in genesis BEFORE starting chain
GENESIS=~/.flora/config/genesis.json
jq '.app_state.evm.params.chain_config.chain_id = "766999"' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"
jq '.app_state.evm.params.chain_config.eip155_block = "0"' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"
```

---

## API & Explorer Issues

### Issue 4: REST API not accessible
**Symptoms**:
- Port 1317 not responding
- Explorer can't connect
- API calls fail

**Solution**:
```bash
# Fix app.toml configuration
APP=~/.flora/config/app.toml

# Enable API
sed -i '/^\[api\]/,/^\[/{
  s/^enable = .*/enable = true/
  s/^swagger = .*/swagger = false/
  s/^address = .*/address = "tcp:\/\/0.0.0.0:1317"/
}' $APP

# Restart florad
pkill florad
nohup florad start > ~/flora.log 2>&1 &
```

**Verification**:
```bash
# Test local API
curl localhost:1317/cosmos/base/tendermint/v1beta1/blocks/latest

# Test external access
curl http://[NODE_IP]:1317/cosmos/base/tendermint/v1beta1/blocks/latest
```

---

### Issue 5: CORS errors in explorer
**Symptoms**:
- Explorer shows: "blocked by CORS policy"
- API responds but browser blocks it

**Solution**:
```bash
# Enable CORS in app.toml
APP=~/.flora/config/app.toml
sed -i '/^\[api\]/a\
# Enable CORS for explorer\
enabled-unsafe-cors = true' $APP

# Also update config.toml for RPC CORS
CONFIG=~/.flora/config/config.toml
sed -i 's/cors_allowed_origins = \[.*\]/cors_allowed_origins = ["*"]/' $CONFIG

# Restart node
pkill florad
nohup florad start > ~/flora.log 2>&1 &
```

---

### Issue 6: Load balancer not routing
**Symptoms**:
- Direct node access works
- https://[api-domain].flora.network doesn't work
- Explorer can't connect

**AWS ALB Configuration Required**:
1. Target Group:
   - Add EC2 instances on port 1317
   - Health check path: `/cosmos/base/tendermint/v1beta1/blocks/latest`

2. Listener Rules:
   - HTTPS:443 → HTTP:1317

3. Security Groups:
   - Allow inbound 1317 from ALB security group

---

## Network Configuration

### Complete Genesis Setup
```bash
# 1. Initialize node
florad init [moniker] --chain-id flora_766999-1

# 2. Set ALL denoms BEFORE creating gentx
GENESIS=~/.flora/config/genesis.json
jq '.app_state.staking.params.bond_denom = "uflora"' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"
jq '.app_state.mint.params.mint_denom = "uflora"' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"
jq '.app_state.crisis.constant_fee.denom = "uflora"' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"
jq '.app_state.evm.params.evm_denom = "uflora"' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"

# 3. Set EVM chain ID for EIP-155
jq '.app_state.evm.params.chain_config.chain_id = "766999"' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"
jq '.app_state.evm.params.chain_config.eip155_block = "0"' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"

# 4. Create validator and gentx
florad keys add validator --keyring-backend test
VALIDATOR=$(florad keys show validator -a --keyring-backend test)
florad genesis add-genesis-account $VALIDATOR 10000000000000000000000000uflora --keyring-backend test
florad genesis gentx validator 1000000000000000000000000uflora \
  --chain-id flora_766999-1 \
  --moniker [moniker] \
  --keyring-backend test

# 5. Add other accounts (if lead node)
# Add other validators, faucet, dev pool, etc.

# 6. CRITICAL: Collect gentxs
florad genesis collect-gentxs

# 7. Enable APIs
APP=~/.flora/config/app.toml
sed -i '/^\[api\]/,/^\[/{
  s/^enable = .*/enable = true/
  s/^address = .*/address = "tcp:\/\/0.0.0.0:1317"/
}' $APP
sed -i '/^\[api\]/a\enabled-unsafe-cors = true' $APP

# Enable JSON-RPC
sed -i '/^\[json-rpc\]/,/^\[/{
  s/^enable = .*/enable = true/
  s/^address = .*/address = "0.0.0.0:8545"/
}' $APP

# 8. Set persistent peers
CONFIG=~/.flora/config/config.toml
sed -i 's/persistent_peers = ""/persistent_peers = "[peer_list]"/' $CONFIG
sed -i 's/cors_allowed_origins = \[.*\]/cors_allowed_origins = ["*"]/' $CONFIG

# 9. Start node
florad start
```

---

## Quick Reference Commands

### Health Checks
```bash
# Check if node is running
ps aux | grep florad

# Check block production
curl localhost:26657/status | jq '.result.sync_info.latest_block_height'

# Check validators
florad query staking validators

# Check REST API
curl localhost:1317/cosmos/base/tendermint/v1beta1/blocks/latest

# Check EVM RPC
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
```

### Debugging
```bash
# View logs
tail -f ~/flora.log

# Check gentx files
ls -la ~/.flora/config/gentx/

# Verify genesis
florad genesis validate

# Check collected gentxs
cat ~/.flora/config/genesis.json | jq '.app_state.genutil.gen_txs | length'

# Check total supply
florad query bank total | jq '.supply[] | select(.denom=="uflora")'
```

### Emergency Recovery
```bash
# Stop everything
pkill florad

# Backup current state
cp -r ~/.flora ~/.flora.backup.$(date +%Y%m%d-%H%M%S)

# Clean restart
rm -rf ~/.flora
# Then follow complete genesis setup above
```

---

## Critical Lessons Learned

1. **Empty delegator_address is NORMAL** - Don't try to fix it
2. **Always run collect-gentxs** - This is the most commonly missed step
3. **Set denoms BEFORE creating gentx** - Otherwise gentx uses wrong denom
4. **Enable CORS for explorers** - Browser security requires this
5. **EIP-155 needs block 0** - Set eip155_block = "0" for correct eth_chainId
6. **Test API endpoints directly first** - Before debugging load balancers
7. **Keep SSH keys safe** - Document access clearly

---

## Explorer-Specific Configuration

### For Ping Pub Explorer
1. REST API must be on port 1317
2. CORS must be enabled
3. Load balancer must route HTTPS→HTTP
4. Endpoints required:
   - `/cosmos/base/tendermint/v1beta1/blocks/latest`
   - `/cosmos/staking/v1beta1/validators`
   - `/cosmos/bank/v1beta1/supply`
   - `/cosmos/base/tendermint/v1beta1/node_info`

### Testing Explorer Connectivity
```bash
# Test all required endpoints
for endpoint in "blocks/latest" "node_info"; do
  echo "Testing $endpoint:"
  curl -s "http://[NODE_IP]:1317/cosmos/base/tendermint/v1beta1/$endpoint" | jq '.[] | keys' | head -5
done

# Test CORS headers
curl -I http://[NODE_IP]:1317/cosmos/base/tendermint/v1beta1/blocks/latest | grep -i "access-control"
```

---

## Checklist for New Launch

- [ ] Set chain-id and denoms in genesis
- [ ] Create validator keys and accounts
- [ ] Generate gentx files
- [ ] **COLLECT GENTXS** (don't forget!)
- [ ] Validate genesis
- [ ] Configure EIP-155 if needed
- [ ] Enable REST API and JSON-RPC
- [ ] Enable CORS
- [ ] Set persistent peers
- [ ] Start validators
- [ ] Verify block production
- [ ] Test API endpoints
- [ ] Configure load balancer
- [ ] Test explorer connection

---

**Remember**: Most problems have simple solutions. Check the basics first!
