# Runbook: EVM ChainId Renumbering & Devnet Regenesis

Status: proposed
Owner: chain-core
Created: 2025-10-15
Related: DEVNET.md, setup-https-rpc.sh, setup-rpc-dns.sh, RPC_SETUP.md, RPC_ENDPOINTS.md, chain_metadata.json

## Summary

We will change the EVM chainId of Flora Devnet to a unique value and perform a controlled regenesis + redeploy. Goal: eliminate MetaMask’s chainId mismatch warnings and ensure a clean developer experience across wallets and tools.

## Problem / Context

- Current EVM chainId: `9000` (0x2328) is mapped to another network in common registries, so wallets (MetaMask) warn during add/switch.
- Warnings are benign but harm UX and trust. A unique chainId removes them.

## Scope

In:
- Ethermint/Evmos EVM chainId change via genesis.
- Devnet re‑genesis + validator/RPC redeploy.
- RPC load balancer swap to the new chain.
- Faucet/indexer/explorer reset (if applicable).
- Client updates (web/app/scripts/tests) coordinated via separate task ticket.

Out:
- Mainnet/testnet changes (devnet only).

## Preconditions

- Candidate chainId chosen and verified unique on public registries.
- Dev images and configs ready for regenesis.
- Maintenance window announced to team (60–90 minutes).

Note: For full isolation from any legacy peers, consider bumping the Cosmos chain-id revision from `flora_7668378-1` to `flora_7668378-2` during this regenesis. This is optional for devnet because the new genesis hash already prevents accidental peering, but many Cosmos networks increment the revision for clarity.

## Selecting a New ChainId

1) Pick a high, unclaimed EIP‑155 decimal (avoid popular/reserved IDs).
2) Verify uniqueness:
   - Search `site:chainid.network <ID>` and `site:chainlist.org <ID>`.
3) Compute hex: `printf "0x%x\n" <DECIMAL>`.

Decision record: store final decimal+hex in `chain_metadata.json`.

### **Selected Chain ID for Devnet: 766999 (0xBB417)**

**Decision Date**: 2025-10-15
**Network**: Devnet only (mainnet reserved separately)
**Verification Status**: ✅ Verified unused on chainlist.org and chainid.network

**Rationale**:
- FLORA base encoding (766) + testnet indicator (999)
- Clearly distinguishes devnet from mainnet
- High enough to avoid common chain ID conflicts
- No collision with existing networks (unlike 9000/Evmos or 7668378/QL1)
- Provides clean MetaMask experience with zero warnings
- Reserves premium chain ID (766793) for mainnet launch

**Mainnet Reserved**: 766793 (0xBB349) - Full FLORA encoding, saved for production

**Alternatives Considered**:
- 766793 (0xBB349) - Reserved for mainnet (premium FLORA encoding)
- 76679 (0x12b87) - Shorter variant, less distinctive
- 420766 (0x66b9e) - Memorable prefix, no FLORA connection
- 7668378 (0x75029a) - Original plan, already used by QL1 Testnet

**Strategic Documentation**: See `docs/CHAIN_ID_STRATEGY.md` for complete network architecture

## Cutover Plan (T‑0 to T+90m)

1) Freeze writes and announce maintenance.
2) Re‑genesis with new chainId.
3) Bring up validator(s) and RPC nodes.
4) Point ALB/DNS `rpc.flora.network` to the new RPC group.
5) Reset indexers/explorer/faucet against the new chain.
6) Verify `eth_chainId` and basic calls.
7) Coordinate client updates; users reconnect and auto‑add the new network without warnings.

## Implementation Steps

1) Update chain config/genesis
- Locate the Ethermint/Evmos module config and set `chain-id = <NEW_DECIMAL>` for EVM (or the corresponding genesis field).
- Ensure Tendermint/Cosmos identifiers remain correct (Cosmos `chain_id` may be separate like `flora_7668378-1`).

2) Re‑genesis & boot nodes
- Generate a fresh genesis with the new EVM chainId.
- Start validators and RPC nodes. Confirm healthy blocks.

3) Swap RPC endpoint
- Update ALB target group / DNS via `setup-https-rpc.sh` and `setup-rpc-dns.sh` so `https://rpc.flora.network` points to new nodes.
- Verify publicly:
  ```bash
  curl -sS -X POST https://rpc.flora.network \\
    -H 'Content-Type: application/json' \\
    --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
  ```
  Expect: `0x<NEW_HEX>`.

4) Tooling resets
- Indexer: wipe/reindex.
- Explorer: reconfigure network and restart.
- Faucet: update chainId and fund new accounts.

5) Communications
- Post “What changed” and “How to remove old network in MetaMask”.

## Acceptance Criteria

- `eth_chainId` on `https://rpc.flora.network` returns `0x<NEW_HEX>`.
- MetaMask adds/switches with zero mismatch warnings.
- Basic calls (eth_blockNumber, gas price, simple tx) succeed.
- Client tickets merged and tested (see 0002).

## Risks & Rollback

- Risk: stale DNS/ALB health checks → users hit old RPC. Mitigation: TTLs low, disable old target group.
- Risk: client code still pinned to 9000. Mitigation: coordinate merge order.
- Rollback: restore ALB to old RPC group and revert client PRs.

## Owners & Timeline

- Chain/Core: regenesis + infra (primary).
- Web/App: client updates (secondary, ticket 0002).
- Timeline: 60–90 minutes window.

## Evidence & References

- DEVNET.md — node bring‑up and validator workflow.
- RPC_SETUP.md / RPC_ENDPOINTS.md — DNS/ALB recipes.
- chain_metadata.json — record final EVM chainId chosen.

## Implementation Log

- 2025-10-15: Draft runbook created. Awaiting chainId decision and window scheduling.
- 2025-10-15: Chain ID decision finalized. Devnet: 766999 (0xBB417), Mainnet reserved: 766793 (0xBB349).
- 2025-10-15: Created comprehensive chain ID strategy document (`docs/CHAIN_ID_STRATEGY.md`).
