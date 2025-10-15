# Task: Update Clients & Scripts to New EVM ChainId

Status: proposed
Owner: web + tooling
Created: 2025-10-15
Related: 0001-runbook-evm-chainid-renumbering-regenesis.md

## Summary

Once the devnet adopts a new EVM chainId, update all client code, scripts, and docs to reference the new ID and hex.

## Changes Required

- Web/app config constants for EVM chainId (decimal and hex).
- Test stubs that return `eth_chainId` (e.g., Playwright/Vitest fixtures).
- Scripts referencing `9000` or `0x2328` (connection checks, demos).
- Docs and FAQs that mention the old ID.

## Implementation Plan

1) Decide final chainId (from runbook 0001) and compute hex.
2) Patch client repos:
   - Update constants and meta (name/symbol/RPC unchanged unless specified).
   - Update tests/stubs to return new hex.
   - Re‑run checks: `npm run check && npm run test && npm run lint` (or equivalents).
3) Validate end‑to‑end:
   - Fresh profile: connect + sign without warnings.
   - Scripts show correct `eth_chainId`.
4) Communicate deprecation of the old ID for devnet.

## Acceptance Criteria

- All clients successfully add/switch to the new chainId with no warnings.
- Tests/scripts green with the new ID.
- Docs reflect the new ID.

## Risks

- Drift between repos — mitigate by searching for both decimal and hex forms.

## Implementation Log

- 2025-10-15: Task created, blocked on 0001 decision.

