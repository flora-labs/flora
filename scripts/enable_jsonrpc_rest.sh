#!/usr/bin/env bash
set -euo pipefail

# Enable JSON-RPC (8545/8546) and Cosmos REST (1317) in app.toml for the current node.
# Usage: ./scripts/enable_jsonrpc_rest.sh [APP_TOML_PATH]

APP_TOML=${1:-"$HOME/.flora/config/app.toml"}

if [ ! -f "$APP_TOML" ]; then
  echo "app.toml not found at: $APP_TOML" >&2
  exit 1
fi

echo "Enabling JSON-RPC and REST in: $APP_TOML"

# JSON-RPC
sed -i "s/^enable *= *.*/enable = true/" "$APP_TOML" || true
sed -i 's#^address *= *".*"#address = "0.0.0.0:8545"#' "$APP_TOML" || true
sed -i 's#^ws-address *= *".*"#ws-address = "0.0.0.0:8546"#' "$APP_TOML" || true
grep -q '^api = ' "$APP_TOML" || echo 'api = "eth,net,web3,debug,personal,txpool"' >> "$APP_TOML"

# REST
sed -i "s/^enable *= *.*/enable = true/" "$APP_TOML" || true
sed -i 's#^address *= *".*"#address = "tcp://0.0.0.0:1317"#' "$APP_TOML" || true
sed -i 's/^enabled-unsafe-cors *= *.*/enabled-unsafe-cors = true/' "$APP_TOML" || true

echo "✅ app.toml updated (JSON-RPC + REST)"

