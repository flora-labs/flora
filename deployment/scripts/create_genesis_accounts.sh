#!/usr/bin/env bash
# Create devnet genesis accounts for faucet and dev pool.
# - Uses keyring backend 'test' (devnet only)
# - Writes addresses to ./genesis_accounts.env and ./genesis_accounts.json

set -euo pipefail

KEYRING=${KEYRING:-test}
OUT_ENV=${OUT_ENV:-genesis_accounts.env}
OUT_JSON=${OUT_JSON:-genesis_accounts.json}

echo "Creating faucet and devpool keys with keyring-backend='$KEYRING'..."

if ! florad keys show faucet --keyring-backend "$KEYRING" >/dev/null 2>&1; then
  florad keys add faucet --keyring-backend "$KEYRING" --output json | tee faucet_key.json >/dev/null
else
  echo "Key 'faucet' already exists; skipping creation."
fi

if ! florad keys show devpool --keyring-backend "$KEYRING" >/dev/null 2>&1; then
  florad keys add devpool --keyring-backend "$KEYRING" --output json | tee devpool_key.json >/dev/null
else
  echo "Key 'devpool' already exists; skipping creation."
fi

FAUCET_ADDR=$(florad keys show faucet -a --keyring-backend "$KEYRING")
DEVPOOL_ADDR=$(florad keys show devpool -a --keyring-backend "$KEYRING")

echo "Writing $OUT_ENV and $OUT_JSON..."
cat > "$OUT_ENV" <<EOF
FAUCET_ADDR=$FAUCET_ADDR
DEVPOOL_ADDR=$DEVPOOL_ADDR
EOF

jq -n --arg faucet "$FAUCET_ADDR" --arg devpool "$DEVPOOL_ADDR" '{faucet_addr:$faucet, devpool_addr:$devpool}' > "$OUT_JSON"

echo "✅ Accounts created. Addresses:"
echo "  FAUCET_ADDR=$FAUCET_ADDR"
echo "  DEVPOOL_ADDR=$DEVPOOL_ADDR"
echo "Note: faucet_key.json and devpool_key.json contain key metadata (devnet only). Store securely." 

