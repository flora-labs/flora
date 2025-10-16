# Issue 0006 — Explorer “Offline” Post‑Regenesis and Wallet eth_chainId Polish

Status: open
Owner: chain-core
Created: 2025-10-16
Related: REGENESIS_STATUS_REPORT.md §16, 0005-devnet-regenesis-blockers.md

## Context
- Devnet successfully regenesis'd and is producing blocks on all three validators.
- JSON‑RPC (8545) and REST (1317) are enabled in app.toml on each node.
- ALB for API has been in place for months and worked with the prior genesis.
- Explorer UI shows Connected UI status but network pane reports Offline/zero height.

## Current Status (2025-10-16 UTC)
- ❌ Chain not yet producing blocks (genesis start blocked; see Issue 0005). Explorer remains “Offline” because the core network has not reached height > 0.
- ✅ JSON‑RPC and REST are enabled by config; REST health path remains unchanged.
- ℹ️ EIP‑155-at-genesis is configured in the prepared genesis (chain_id=766999, eip155_block="0"). eth_chainId will report 0xBB417 once the chain starts.

## Likely Causes (ordered by probability)
1) Explorer reading old genesis index (stateless client talks to REST; still needs to point at a fresh chain state). 
2) REST proxy health path check (ALB) expecting node_info on 1317; verify targets green.
3) Node API binding — addressed by app.toml enable + 0.0.0.0 addresses.

## Facts Collected
- Nodes: Genesis 52.9.17.25 (lead), Guardian 50.18.34.12, Nexus 204.236.162.240
- Cosmos chain‑id: flora_7668378-1 (unchanged)
- EVM params: chain_config.chain_id = 766999
- JSON‑RPC: eth_chainId currently 0x75029a (Tendermint net id) because eip155_block was not set at genesis.

## Required Actions (Explorer)
- Blocked by core chain bring‑up. After validators reach height > 0:
  1) Keep base REST at https://devnet-api.flora.network (no ALB changes).
  2) If UI caches prior state, clear CDN/browser cache; otherwise the explorer should show Connected automatically.
  3) Confirm height > 0 and supply populated.
- Verify ALB targets for 1317 are green; health path: /cosmos/base/tendermint/v1beta1/node_info.

## Required Actions (Wallets) — Option A (selected)
- Short polish regenesis (devnet, ~20–30 min), no application code changes:
  - In lead genesis BEFORE collect:
    - app_state.evm.params.chain_config.chain_id = "766999"
    - app_state.evm.params.chain_config.eip155_block = "0"
    - (optional) set other EIP blocks (homestead/london/berlin/…) to "0" for completeness
  - Denoms: staking/mint/crisis/evm = "uflora" pre‑gentx on all nodes
  - Allocations in genesis: 10M × 3 validators; faucet 10M; dev pool 1M; reserve 9M → total 50M
  - Gentx: stock CLI with `--from validator --keyring-backend test` (no JSON edits)
  - Lead: collect‑gentxs; validate; distribute; restart
  - Verify: eth_chainId over JSON‑RPC = 0xBB417; on‑chain EVM params chain_config.chain_id=766999

## Verification Checklist
- After chain starts:
  - REST (1317) via ALB: curl https://devnet-api.flora.network/cosmos/base/tendermint/v1beta1/node_info → network flora_7668378-1
  - Comet RPC (if proxied): height > 0
  - Explorer shows “Connected”, height > 0, supply = 50M
  - Wallets: eth_chainId=0xBB417 (766999); net_version=7668378 (expected mismatch on Cosmos‑EVM)

## Acceptance Criteria
- Explorer “Connected” with height progressing and supply populated
- JSON‑RPC reachable and eth_chainId returns 0xBB417
- No changes to ALB configuration required
