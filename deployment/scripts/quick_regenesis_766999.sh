#!/bin/bash
# Quick Devnet Regenesis / Gentx Helper - Chain ID 766999
# Purpose: Prepare devnet genesis with unique EVM chain ID, avoiding 9000/Evmos conflict.
# NOTE: This WIPES existing data for the selected role. Use only for devnet!

set -euo pipefail

ROLE=${ROLE:-validator}  # validator | lead
CHAIN_ID="flora_7668378-1"   # Cosmos chain-id stays stable (Option A)
EVM_CHAIN_ID="766999"         # EVM chain id (decimal)
EVM_CHAIN_ID_HEX="0xBB417"    # EVM chain id (hex)
MONIKER=${1:-"Flora-Node"}
KEYRING="test"

# Allocations (uflora)
VAL_ALLOCATION_UFLORA=10000000000000000000000000    # 10M
VAL_SELF_STAKE_UFLORA=1000000000000000000000000     # 1M
FAUCET_ALLOCATION_UFLORA=10000000000000000000000000 # 10M
DEVPOOL_ALLOCATION_UFLORA=1000000000000000000000000 # 1M

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║      Flora Devnet Genesis Helper - Chain ID ${EVM_CHAIN_ID}          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo "Role: $ROLE  |  Moniker: $MONIKER"
echo ""
echo "⚠️  WARNING: This will DELETE existing chain data for $USER on this node."
read -p "Type 'YES' to continue: " confirm
if [ "${confirm}" != "YES" ]; then
  echo "Aborted."; exit 1
fi

echo "🛑 Stopping florad (if running)..."
sudo systemctl stop florad 2>/dev/null || true
sleep 1

echo "🧹 Resetting local chain data..."
florad tendermint unsafe-reset-all || florad comet unsafe-reset-all
rm -rf "$HOME/.flora/config/genesis.json" "$HOME/.flora/config/gentx/"

echo "🔧 Initializing new chain..."
florad init "$MONIKER" --chain-id "$CHAIN_ID"

echo "🪙 Setting all denoms to uflora (pre-gentx)..."
GENESIS_JSON="$HOME/.flora/config/genesis.json"
jq '.app_state.staking.params.bond_denom = "uflora"' "$GENESIS_JSON" > "$GENESIS_JSON.tmp" && mv "$GENESIS_JSON.tmp" "$GENESIS_JSON"
jq '.app_state.mint.params.mint_denom = "uflora"'   "$GENESIS_JSON" > "$GENESIS_JSON.tmp" && mv "$GENESIS_JSON.tmp" "$GENESIS_JSON"
jq '.app_state.crisis.constant_fee.denom = "uflora"' "$GENESIS_JSON" > "$GENESIS_JSON.tmp" && mv "$GENESIS_JSON.tmp" "$GENESIS_JSON"
jq '.app_state.evm.params.evm_denom = "uflora"'      "$GENESIS_JSON" > "$GENESIS_JSON.tmp" && mv "$GENESIS_JSON.tmp" "$GENESIS_JSON"

echo "🔑 Ensuring validator key exists..."
if ! florad keys show validator --keyring-backend "$KEYRING" >/dev/null 2>&1; then
  florad keys add validator --keyring-backend "$KEYRING" --output json 2>&1 | tee validator_key.json
fi
VALIDATOR_ADDR=$(florad keys show validator -a --keyring-backend "$KEYRING")
echo "Validator address: $VALIDATOR_ADDR"

if [ "$ROLE" = "validator" ]; then
  echo "💰 Adding genesis account for validator (10M FLORA)..."
  florad genesis add-genesis-account "$VALIDATOR_ADDR" ${VAL_ALLOCATION_UFLORA}uflora

  echo "⚡ Creating gentx (self-stake 1M FLORA)..."
  florad genesis gentx validator ${VAL_SELF_STAKE_UFLORA}uflora \
    --chain-id "$CHAIN_ID" \
    --moniker "$MONIKER" \
    --commission-rate="0.10" \
    --commission-max-rate="0.20" \
    --commission-max-change-rate="0.01" \
    --min-self-delegation="1" \
    --from validator \
    --keyring-backend "$KEYRING"

  echo "🔎 Sanity: delegator and denom in gentx..."
  GX_FILE=$(ls "$HOME/.flora/config/gentx"/gentx-*.json)
  DELEGATOR=$(jq -r '.body.messages[0].delegator_address' "$GX_FILE")
  DENOM=$(jq -r '.body.messages[0].value.denom' "$GX_FILE")
  if [[ -z "$DELEGATOR" || "$DELEGATOR" == "null" ]]; then
    echo "❌ Empty delegator_address in gentx. Aborting."; exit 1
  fi
  if [[ "$DENOM" != "uflora" ]]; then
    echo "❌ Wrong denom in gentx ($DENOM). Expected uflora."; exit 1
  fi
  echo "✅ Gentx OK: delegator=$DELEGATOR denom=$DENOM"

  echo "📤 Gentx ready at: $HOME/.flora/config/gentx/"
  echo "➡️  Send gentx to the lead node for collection."
  echo "✅ Validator preparation complete."
  exit 0
fi

if [ "$ROLE" = "lead" ]; then
  # Require FAUCET_ADDR/DEVPOOL_ADDR; if missing, try to source ./genesis_accounts.env
  if [ -z "${FAUCET_ADDR:-}" ] || [ -z "${DEVPOOL_ADDR:-}" ]; then
    if [ -f ./genesis_accounts.env ]; then
      echo "Sourcing ./genesis_accounts.env for faucet/devpool addresses..."
      # shellcheck disable=SC1091
      source ./genesis_accounts.env
    fi
  fi
  # If not provided, create local keys for faucet/devpool/reserve
  if [ -z "${FAUCET_ADDR:-}" ]; then
    florad keys add faucet --keyring-backend "$KEYRING" >/dev/null 2>&1 || true
    FAUCET_ADDR=$(florad keys show faucet -a --keyring-backend "$KEYRING")
  fi
  if [ -z "${DEVPOOL_ADDR:-}" ]; then
    florad keys add devpool --keyring-backend "$KEYRING" >/dev/null 2>&1 || true
    DEVPOOL_ADDR=$(florad keys show devpool -a --keyring-backend "$KEYRING")
  fi
  if [ -z "${RESERVE_ADDR:-}" ]; then
    florad keys add reserve --keyring-backend "$KEYRING" >/dev/null 2>&1 || true
    RESERVE_ADDR=$(florad keys show reserve -a --keyring-backend "$KEYRING")
  fi
  : "${FAUCET_ADDR?Faucet address not set and could not be created}"
  : "${DEVPOOL_ADDR?Dev pool address not set and could not be created}"
  : "${RESERVE_ADDR?Reserve address not set and could not be created}"
  OTHER_VALIDATOR_ADDRS=${OTHER_VALIDATOR_ADDRS:-""} # space-separated flora1... addresses

  GENTX_DIR="$HOME/.flora/config/gentx"

  echo "🧩 Setting EVM chain config (chain_id=${EVM_CHAIN_ID}, eip155_block=0) before gentx/collect..."
  jq --arg cid "$EVM_CHAIN_ID" '.app_state.evm.params.chain_config.chain_id = $cid' "$GENESIS_JSON" > "$GENESIS_JSON.tmp" && mv "$GENESIS_JSON.tmp" "$GENESIS_JSON"
  jq '.app_state.evm.params.chain_config.eip155_block = "0"' "$GENESIS_JSON" > "$GENESIS_JSON.tmp" && mv "$GENESIS_JSON.tmp" "$GENESIS_JSON"

  add_account_once() {
    local addr="$1"; local amount_uflora="$2"
    if jq -e --arg a "$addr" '.app_state.bank.balances[]? | select(.address==$a)' "$GENESIS_JSON" >/dev/null; then
      echo "ℹ️  Account already present, skipping: $addr"
    else
      florad genesis add-genesis-account "$addr" ${amount_uflora}uflora
    fi
  }

  extract_addrs_from_gentx() {
    # Try multiple shapes for gentx JSON
    jq -r 'try(.body.messages[]? | select(."@type"? and (."@type"|test("MsgCreateValidator"))) | .delegator_address) // empty' "$@" 2>/dev/null
    jq -r 'try(.msg[0].value.delegator_address) // empty' "$@" 2>/dev/null
    jq -r 'try(.value.delegator_address) // empty' "$@" 2>/dev/null
  }

  echo "💰 Adding lead validator genesis account (10M FLORA)..."
  add_account_once "$VALIDATOR_ADDR" ${VAL_ALLOCATION_UFLORA}

  # Build validator addr set: explicit env + extracted from gentx files
  ADDR_SET=""
  if [ -n "$OTHER_VALIDATOR_ADDRS" ]; then
    ADDR_SET="$ADDR_SET $OTHER_VALIDATOR_ADDRS"
  fi
  if [ -d "$GENTX_DIR" ]; then
    mapfile -t extracted < <(extract_addrs_from_gentx "$GENTX_DIR"/*.json | sort -u)
    for a in "${extracted[@]}"; do
      [ -n "$a" ] && ADDR_SET="$ADDR_SET $a"
    done
  fi

  # Mint 10M to each peer validator (excluding lead if present)
  for addr in $ADDR_SET; do
    if [ "$addr" != "$VALIDATOR_ADDR" ]; then
      echo "💰 Adding peer validator account (10M FLORA): $addr"
      add_account_once "$addr" ${VAL_ALLOCATION_UFLORA}
    fi
  done

  echo "💧 Adding faucet account (10M FLORA): $FAUCET_ADDR"
  add_account_once "$FAUCET_ADDR" ${FAUCET_ALLOCATION_UFLORA}

  echo "🛠️  Adding dev pool account (1M FLORA): $DEVPOOL_ADDR"
  add_account_once "$DEVPOOL_ADDR" ${DEVPOOL_ALLOCATION_UFLORA}
  echo "🏦 Adding reserve account (9M FLORA): $RESERVE_ADDR"
  add_account_once "$RESERVE_ADDR" 9000000000000000000000000

  echo "⚡ Creating gentx for lead (self-stake 1M FLORA)..."
  florad genesis gentx validator ${VAL_SELF_STAKE_UFLORA}uflora \
    --chain-id "$CHAIN_ID" \
    --moniker "$MONIKER" \
    --commission-rate="0.10" \
    --commission-max-rate="0.20" \
    --commission-max-change-rate="0.01" \
    --min-self-delegation="1" \
    --from validator \
    --keyring-backend "$KEYRING"

  echo "🔎 Sanity: delegator and denom in lead gentx..."
  GX_FILE="$GENTX_DIR"/gentx-*.json
  DELEGATOR=$(jq -r '.body.messages[0].delegator_address' $GX_FILE)
  DENOM=$(jq -r '.body.messages[0].value.denom' $GX_FILE)
  if [[ -z "$DELEGATOR" || "$DELEGATOR" == "null" ]]; then
    echo "❌ Empty delegator_address in lead gentx. Aborting."; exit 1
  fi
  if [[ "$DENOM" != "uflora" ]]; then
    echo "❌ Wrong denom in lead gentx ($DENOM). Expected uflora."; exit 1
  fi
  echo "✅ Lead gentx OK: delegator=$DELEGATOR denom=$DENOM"

  echo "📦 Collecting all gentxs (ensure peer gentx files are in ~/.flora/config/gentx/)..."
  florad genesis collect-gentxs

  echo "🧪 Validating genesis..."
  florad genesis validate

  echo "🔧 Enabling JSON-RPC and REST in app.toml..."
  APP_TOML="$HOME/.flora/config/app.toml"
  # JSON-RPC enablement
  sed -i "s/^enable *= *.*/enable = true/" "$APP_TOML" || true
  sed -i 's#^address *= *".*"#address = "0.0.0.0:8545"#' "$APP_TOML" || true
  sed -i 's#^ws-address *= *".*"#ws-address = "0.0.0.0:8546"#' "$APP_TOML" || true
  if ! grep -q '^api = ' "$APP_TOML"; then
    echo 'api = "eth,net,web3,debug,personal,txpool"' >> "$APP_TOML"
  fi
  # REST enablement (Cosmos API)
  sed -i "s/^enable *= *.*/enable = true/" "$APP_TOML" || true
  sed -i 's#^address *= *".*"#address = "tcp://0.0.0.0:1317"#' "$APP_TOML" || true
  sed -i 's/^enabled-unsafe-cors *= *.*/enabled-unsafe-cors = true/' "$APP_TOML" || true

  echo "🔐 Calculating genesis hash..."
  GENESIS_HASH=$(sha256sum "$GENESIS_JSON" | awk '{print $1}')
  echo "Genesis SHA256: $GENESIS_HASH"

  echo ""
  echo "╔════════════════════════════════════════════════════════════════╗"
  echo "║                  GENESIS FINALIZATION COMPLETE                  ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo "✅ Chain ID (Cosmos): ${CHAIN_ID}"
  echo "✅ Chain ID (EVM):    ${EVM_CHAIN_ID} (${EVM_CHAIN_ID_HEX})"
  echo "✅ Validator address: $VALIDATOR_ADDR"
  echo "✅ Genesis hash:      $GENESIS_HASH"
  echo ""
  echo "Next steps:"
  echo "1) Distribute genesis.json to other validators"
  echo "2) Configure persistent_peers on each node"
  echo "3) Start validators and verify eth_chainId returns ${EVM_CHAIN_ID_HEX} (EIP-155 active)"
  exit 0
fi

echo "Unknown ROLE: $ROLE" >&2
exit 2
