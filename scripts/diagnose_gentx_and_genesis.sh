#!/usr/bin/env bash
set -euo pipefail
G=${G:-$HOME/.flora/config/genesis.json}
GX_DIR=${GX_DIR:-$HOME/.flora/config/gentx}

echo "== Genesis denom summary (staking/mint/crisis/evm) =="
jq -r '.app_state.staking.params.bond_denom as $b | .app_state.mint.params.mint_denom as $m | .app_state.crisis.constant_fee.denom as $c | .app_state.evm.params.evm_denom as $e | "bond_denom=",$b," mint_denom=",$m," crisis_denom=",$c," evm_denom=",$e' "$G"

echo
echo "== EVM chain_id param =="
jq -r '.app_state.evm.params.chain_config.chain_id // "(missing)"' "$G"

echo
echo "== Gentx files and delegator_address/denom =="
ls -1 "$GX_DIR"/*.json 2>/dev/null || { echo "(no gentx files)"; exit 0; }
for f in "$GX_DIR"/*.json; do
  echo "FILE: $f"
  jq -r '.body.messages[0].delegator_address // "(none)"' "$f"
  jq -r '.body.messages[0].value.denom // "(none)"' "$f"
  echo "---"
done

