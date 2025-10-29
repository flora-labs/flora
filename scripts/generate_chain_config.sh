#!/usr/bin/env bash
set -euo pipefail

# Generate Flora chain configs from example templates by injecting addresses derived
# from provided mnemonics or generating fresh dev mnemonics using florad.
#
# Supported templates: standalone | self-ibc | testnet
#
# Environment inputs (examples)
#   ACC0_MNEMONIC, ACC1_MNEMONIC, USER0_MNEMONIC, USER1_MNEMONIC
#   For self-ibc second chain, optionally: ACC0_MNEMONIC_2, ACC1_MNEMONIC_2, USER0_MNEMONIC_2, USER1_MNEMONIC_2
#   For testnet Gaia placeholders: GAIA_ACC0_ADDRESS, GAIA_ACC1_ADDRESS, GAIA_USER0_ADDRESS, GAIA_USER1_ADDRESS
#   Optional chain id overrides: CHAIN_ID, CHAIN_ID_2
#
# Outputs:
#   - chains/generated/<template>.json
#   - chains/generated/addresses.env, addresses.json (includes any generated mnemonics)
#
# Requirements: florad, jq, sed

usage() {
  cat <<'EOF'
Usage:
  scripts/generate_chain_config.sh -t TEMPLATE [-o OUT_DIR]

Options:
  -t, --template   Template name: standalone | self-ibc | testnet  (default: standalone)
  -o, --out        Output directory (default: chains/generated)
  -h, --help       Show this help and exit

Env inputs:
  ACC0_MNEMONIC, ACC1_MNEMONIC, USER0_MNEMONIC, USER1_MNEMONIC
  ACC0_MNEMONIC_2, ACC1_MNEMONIC_2, USER0_MNEMONIC_2, USER1_MNEMONIC_2 (self-ibc only)
  GAIA_ACC0_ADDRESS, GAIA_ACC1_ADDRESS, GAIA_USER0_ADDRESS, GAIA_USER1_ADDRESS (testnet, optional)
  CHAIN_ID (overrides primary), CHAIN_ID_2 (overrides secondary for self-ibc)

Notes:
  - This script uses a temporary key home and keyring-backend test to derive addresses.
  - Generated mnemonics are written to chains/generated/addresses.json for local use. DO NOT COMMIT.
EOF
}

TEMPLATE="standalone"
OUT_DIR="chains/generated"

# Parse args
while [ $# -gt 0 ]; do
  case "$1" in
    -t|--template)
      TEMPLATE="${2:-}"; shift 2 ;;
    --template=*)
      TEMPLATE="${1#*=}"; shift 1 ;;
    -o|--out)
      OUT_DIR="${2:-}"; shift 2 ;;
    --out=*)
      OUT_DIR="${1#*=}"; shift 1 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

case "$TEMPLATE" in
  standalone) TEMPLATE_FILE="chains/standalone.example.json"; OUT_FILE="$OUT_DIR/standalone.json" ;;
  self-ibc)   TEMPLATE_FILE="chains/self-ibc.example.json";   OUT_FILE="$OUT_DIR/self-ibc.json" ;;
  testnet)    TEMPLATE_FILE="chains/testnet.example.json";    OUT_FILE="$OUT_DIR/testnet.json" ;;
  *)
    echo "Unsupported template: $TEMPLATE" >&2; exit 2 ;;
esac

# Dependencies
command -v florad >/dev/null 2>&1 || { echo "florad not found in PATH"; exit 1; }
command -v jq     >/dev/null 2>&1 || { echo "jq not found in PATH"; exit 1; }
command -v sed    >/dev/null 2>&1 || { echo "sed not found in PATH"; exit 1; }

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Template not found: $TEMPLATE_FILE" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

TMP_HOME="$(mktemp -d -t flora-keys-XXXXXX)"
cleanup() {
  rm -rf "$TMP_HOME"
}
trap cleanup EXIT

KEYRING="test"
KEYALGO="eth_secp256k1"

# Derive or generate a key, returning address; if mnemonic is empty, generate and capture it
derive_address() {
  local key_name="$1"
  local mnemonic_in="$2"
  local addr=""
  local gen_mnemonic=""

  if [ -n "$mnemonic_in" ]; then
    # Recover from provided mnemonic
    printf "%s\n" "$mnemonic_in" | florad keys add "$key_name" --keyring-backend "$KEYRING" --home "$TMP_HOME" --algo "$KEYALGO" --recover >/dev/null
  else
    # Generate new
    local json_out
    if ! json_out="$(florad keys add "$key_name" --keyring-backend "$KEYRING" --home "$TMP_HOME" --algo "$KEYALGO" --output json 2>/dev/null)"; then
      echo "Failed to generate key: $key_name" >&2
      exit 1
    fi
    gen_mnemonic="$(printf "%s" "$json_out" | jq -r '.mnemonic // empty')"
  fi

  addr="$(florad keys show "$key_name" -a --keyring-backend "$KEYRING" --home "$TMP_HOME")"
  printf "%s\n%s\n" "$addr" "$gen_mnemonic"
}

# Primary chain addresses
ACC0_MNEMONIC="${ACC0_MNEMONIC:-}"
ACC1_MNEMONIC="${ACC1_MNEMONIC:-}"
USER0_MNEMONIC="${USER0_MNEMONIC:-}"
USER1_MNEMONIC="${USER1_MNEMONIC:-}"

read -r ACC0_ADDRESS ACC0_GEN_MNEMONIC < <(derive_address "acc0" "$ACC0_MNEMONIC")
read -r ACC1_ADDRESS ACC1_GEN_MNEMONIC < <(derive_address "acc1" "$ACC1_MNEMONIC")
read -r USER0_ADDRESS USER0_GEN_MNEMONIC < <(derive_address "user0" "$USER0_MNEMONIC")
read -r USER1_ADDRESS USER1_GEN_MNEMONIC < <(derive_address "user1" "$USER1_MNEMONIC")

# Secondary chain addresses for self-ibc
ACC0_MNEMONIC_2="${ACC0_MNEMONIC_2:-${ACC0_MNEMONIC:-}}"
ACC1_MNEMONIC_2="${ACC1_MNEMONIC_2:-${ACC1_MNEMONIC:-}}"
USER0_MNEMONIC_2="${USER0_MNEMONIC_2:-${USER0_MNEMONIC:-}}"
USER1_MNEMONIC_2="${USER1_MNEMONIC_2:-${USER1_MNEMONIC:-}}"

if [ "$TEMPLATE" = "self-ibc" ]; then
  read -r ACC0_ADDRESS_2 ACC0_GEN_MNEMONIC_2 < <(derive_address "acc0_2" "$ACC0_MNEMONIC_2")
  read -r ACC1_ADDRESS_2 ACC1_GEN_MNEMONIC_2 < <(derive_address "acc1_2" "$ACC1_MNEMONIC_2")
  read -r USER0_ADDRESS_2 USER0_GEN_MNEMONIC_2 < <(derive_address "user0_2" "$USER0_MNEMONIC_2")
  read -r USER1_ADDRESS_2 USER1_GEN_MNEMONIC_2 < <(derive_address "user1_2" "$USER1_MNEMONIC_2")
fi

# Optional Gaia addresses for testnet template (leave placeholders if not provided)
GAIA_ACC0_ADDRESS="${GAIA_ACC0_ADDRESS:-}"
GAIA_ACC1_ADDRESS="${GAIA_ACC1_ADDRESS:-}"
GAIA_USER0_ADDRESS="${GAIA_USER0_ADDRESS:-}"
GAIA_USER1_ADDRESS="${GAIA_USER1_ADDRESS:-}"

# Prepare sed expressions for replacements
SED_EXPR=()
SED_EXPR+=(-e "s|\${ACC0_ADDRESS}|${ACC0_ADDRESS}|g")
SED_EXPR+=(-e "s|\${ACC1_ADDRESS}|${ACC1_ADDRESS}|g")
SED_EXPR+=(-e "s|\${USER0_ADDRESS}|${USER0_ADDRESS}|g")
SED_EXPR+=(-e "s|\${USER1_ADDRESS}|${USER1_ADDRESS}|g")

if [ "$TEMPLATE" = "self-ibc" ]; then
  SED_EXPR+=(-e "s|\${ACC0_ADDRESS_2}|${ACC0_ADDRESS_2}|g")
  SED_EXPR+=(-e "s|\${ACC1_ADDRESS_2}|${ACC1_ADDRESS_2}|g")
  SED_EXPR+=(-e "s|\${USER0_ADDRESS_2}|${USER0_ADDRESS_2}|g")
  SED_EXPR+=(-e "s|\${USER1_ADDRESS_2}|${USER1_ADDRESS_2}|g")
fi

if [ "$TEMPLATE" = "testnet" ]; then
  if [ -n "$GAIA_ACC0_ADDRESS" ]; then SED_EXPR+=(-e "s|\${GAIA_ACC0_ADDRESS}|${GAIA_ACC0_ADDRESS}|g"); fi
  if [ -n "$GAIA_ACC1_ADDRESS" ]; then SED_EXPR+=(-e "s|\${GAIA_ACC1_ADDRESS}|${GAIA_ACC1_ADDRESS}|g"); fi
  if [ -n "$GAIA_USER0_ADDRESS" ]; then SED_EXPR+=(-e "s|\${GAIA_USER0_ADDRESS}|${GAIA_USER0_ADDRESS}|g"); fi
  if [ -n "$GAIA_USER1_ADDRESS" ]; then SED_EXPR+=(-e "s|\${GAIA_USER1_ADDRESS}|${GAIA_USER1_ADDRESS}|g"); fi
fi

# Chain ID overrides
if [ -n "${CHAIN_ID:-}" ]; then
  SED_EXPR+=(-e "s|\"chain_id\": *\"flora_766999-1\"|\"chain_id\": \"${CHAIN_ID}\"|g")
fi
if [ -n "${CHAIN_ID_2:-}" ] && [ "$TEMPLATE" = "self-ibc" ]; then
  SED_EXPR+=(-e "s|\"chain_id\": *\"flora_766999-2\"|\"chain_id\": \"${CHAIN_ID_2}\"|g")
fi

# Render file
sed "${SED_EXPR[@]}" "$TEMPLATE_FILE" > "$OUT_FILE"

# Write addresses summary (and any generated mnemonics)
SUMMARY_ENV="$OUT_DIR/addresses.env"
SUMMARY_JSON="$OUT_DIR/addresses.json"

{
  echo "# DO NOT COMMIT. Generated by scripts/generate_chain_config.sh"
  echo "ACC0_ADDRESS=${ACC0_ADDRESS}"
  echo "ACC1_ADDRESS=${ACC1_ADDRESS}"
  echo "USER0_ADDRESS=${USER0_ADDRESS}"
  echo "USER1_ADDRESS=${USER1_ADDRESS}"
  if [ "$TEMPLATE" = "self-ibc" ]; then
    echo "ACC0_ADDRESS_2=${ACC0_ADDRESS_2}"
    echo "ACC1_ADDRESS_2=${ACC1_ADDRESS_2}"
    echo "USER0_ADDRESS_2=${USER0_ADDRESS_2}"
    echo "USER1_ADDRESS_2=${USER1_ADDRESS_2}"
  fi
  if [ "$TEMPLATE" = "testnet" ]; then
    [ -n "$GAIA_ACC0_ADDRESS" ] && echo "GAIA_ACC0_ADDRESS=${GAIA_ACC0_ADDRESS}"
    [ -n "$GAIA_ACC1_ADDRESS" ] && echo "GAIA_ACC1_ADDRESS=${GAIA_ACC1_ADDRESS}"
    [ -n "$GAIA_USER0_ADDRESS" ] && echo "GAIA_USER0_ADDRESS=${GAIA_USER0_ADDRESS}"
    [ -n "$GAIA_USER1_ADDRESS" ] && echo "GAIA_USER1_ADDRESS=${GAIA_USER1_ADDRESS}"
  fi
} > "$SUMMARY_ENV"

jq -n \
  --arg acc0 "$ACC0_ADDRESS" \
  --arg acc1 "$ACC1_ADDRESS" \
  --arg user0 "$USER0_ADDRESS" \
  --arg user1 "$USER1_ADDRESS" \
  --arg acc0m "$ACC0_GEN_MNEMONIC" \
  --arg acc1m "$ACC1_GEN_MNEMONIC" \
  --arg user0m "$USER0_GEN_MNEMONIC" \
  --arg user1m "$USER1_GEN_MNEMONIC" \
  --arg acc0_2 "${ACC0_ADDRESS_2:-}" \
  --arg acc1_2 "${ACC1_ADDRESS_2:-}" \
  --arg user0_2 "${USER0_ADDRESS_2:-}" \
  --arg user1_2 "${USER1_ADDRESS_2:-}" \
  --arg acc0m_2 "${ACC0_GEN_MNEMONIC_2:-}" \
  --arg acc1m_2 "${ACC1_GEN_MNEMONIC_2:-}" \
  --arg user0m_2 "${USER0_GEN_MNEMONIC_2:-}" \
  --arg user1m_2 "${USER1_GEN_MNEMONIC_2:-}" \
  --arg ga0 "${GAIA_ACC0_ADDRESS:-}" \
  --arg ga1 "${GAIA_ACC1_ADDRESS:-}" \
  --arg gu0 "${GAIA_USER0_ADDRESS:-}" \
  --arg gu1 "${GAIA_USER1_ADDRESS:-}" \
  '{
    do_not_commit: true,
    flora: {
      acc0: { address: $acc0, mnemonic: $acc0m },
      acc1: { address: $acc1, mnemonic: $acc1m },
      user0: { address: $user0, mnemonic: $user0m },
      user1: { address: $user1, mnemonic: $user1m }
    },
    flora2: ( ($acc0_2|length) > 0 or ($acc1_2|length) > 0 or ($user0_2|length) > 0 or ($user1_2|length) > 0 )
            as $has2 | if $has2 then {
      acc0: { address: $acc0_2, mnemonic: $acc0m_2 },
      acc1: { address: $acc1_2, mnemonic: $acc1m_2 },
      user0: { address: $user0_2, mnemonic: $user0m_2 },
      user1: { address: $user1_2, mnemonic: $user1m_2 }
    } else null end,
    gaia: ( ($ga0|length) > 0 or ($ga1|length) > 0 or ($gu0|length) > 0 or ($gu1|length) > 0 )
          as $hasg | if $hasg then {
      acc0: $ga0, acc1: $ga1, user0: $gu0, user1: $gu1
    } else null end
  }' > "$SUMMARY_JSON"

echo "Wrote: $OUT_FILE"
echo "Summary: $SUMMARY_ENV, $SUMMARY_JSON"
echo "Done."