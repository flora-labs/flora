#!/bin/bash
# Quick Devnet Regenesis - Chain ID 766999
# Purpose: Fix MetaMask warnings by using unique chain ID
# NOTE: This WIPES all existing data - use only for devnet!

set -e

CHAIN_ID="flora_7668378-1"
EVM_CHAIN_ID="766999"
MONIKER=${1:-"Flora-Node"}
KEYRING="test"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║        Flora Devnet Quick Regenesis - Chain ID 766999          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "⚠️  WARNING: This will DELETE all existing chain data!"
echo "⚠️  Current chain state will be LOST!"
echo ""
read -p "Type 'YES' to continue: " confirm

if [ "$confirm" != "YES" ]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "🗑️  Step 1: Stopping florad..."
sudo systemctl stop florad 2>/dev/null || true
sleep 2

echo "🗑️  Step 2: Wiping old chain data..."
florad tendermint unsafe-reset-all
rm -rf ~/.flora/config/genesis.json
rm -rf ~/.flora/config/gentx/

echo "🔧 Step 3: Initializing new chain..."
florad init $MONIKER --chain-id $CHAIN_ID

echo "🔑 Step 4: Creating validator key..."
florad keys add validator --keyring-backend $KEYRING --output json 2>&1 | tee validator_key.json
VALIDATOR_ADDR=$(florad keys show validator -a --keyring-backend $KEYRING)
echo "Validator address: $VALIDATOR_ADDR"

echo "💰 Step 5: Adding genesis account (100M FLORA)..."
florad genesis add-genesis-account $VALIDATOR_ADDR 100000000000000000000000000uflora

echo "⚡ Step 6: Creating genesis transaction (stake 10M FLORA)..."
florad genesis gentx validator 10000000000000000000000000uflora \
  --chain-id $CHAIN_ID \
  --moniker $MONIKER \
  --commission-rate="0.10" \
  --commission-max-rate="0.20" \
  --commission-max-change-rate="0.01" \
  --min-self-delegation="1" \
  --keyring-backend $KEYRING

echo "📦 Step 7: Collecting genesis transactions..."
florad genesis collect-gentxs

echo "🔧 Step 8: Setting EVM chain ID to 766999..."
cat ~/.flora/config/genesis.json | \
  jq '.app_state.evm.params.chain_config.chain_id = "766999"' \
  > ~/.flora/config/tmp_genesis.json && \
  mv ~/.flora/config/tmp_genesis.json ~/.flora/config/genesis.json

echo "✅ Step 9: Validating genesis..."
florad genesis validate-genesis

echo "🔐 Step 10: Calculating genesis hash..."
GENESIS_HASH=$(sha256sum ~/.flora/config/genesis.json | awk '{print $1}')
echo "Genesis SHA256: $GENESIS_HASH"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    REGENESIS COMPLETE!                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "✅ Chain ID (Cosmos): flora_7668378-1"
echo "✅ Chain ID (EVM):    766999 (0xbb3e7)"
echo "✅ Validator address: $VALIDATOR_ADDR"
echo "✅ Genesis hash:      $GENESIS_HASH"
echo ""
echo "📝 Validator key saved to: validator_key.json"
echo "⚠️  BACKUP THIS FILE SECURELY!"
echo ""
echo "Next steps:"
echo "1. Start the chain:  sudo systemctl start florad"
echo "2. Check logs:       journalctl -u florad -f"
echo "3. Verify EVM ID:    curl -X POST http://localhost:8545 \\"
echo "                        -H 'Content-Type: application/json' \\"
echo "                        -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_chainId\",\"params\":[],\"id\":1}'"
echo ""
