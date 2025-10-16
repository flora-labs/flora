#!/usr/bin/env bash
set -euo pipefail

KEYRING=${KEYRING:-test}
GX_DIR=${GX_DIR:-$HOME/.flora/config/gentx}

if ! florad keys show validator -a --keyring-backend "$KEYRING" >/dev/null 2>&1; then
  echo "validator key not found in keyring=$KEYRING" >&2
  exit 1
fi

DELEGATOR=$(florad keys show validator -a --keyring-backend "$KEYRING")
echo "Using delegator address: $DELEGATOR"

shopt -s nullglob
files=("$GX_DIR"/gentx-*.json)
if [ ${#files[@]} -eq 0 ]; then
  echo "No gentx files in $GX_DIR" >&2
  exit 1
fi

for f in "${files[@]}"; do
  echo "Repairing $f"
  tmp="$f.tmp"
  # Inject delegator_address and denom (uflora)
  jq '.body.messages[0].delegator_address = "'$DELEGATOR'" | .body.messages[0].value.denom = "uflora"' "$f" > "$tmp"
  mv "$tmp" "$f"
  echo "  now: delegator=$(jq -r '.body.messages[0].delegator_address' "$f") denom=$(jq -r '.body.messages[0].value.denom' "$f")"
done

echo "✅ gentx files repaired."

