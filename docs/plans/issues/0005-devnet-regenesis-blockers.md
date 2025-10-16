# Issue 0005 — Devnet Regenesis Blockers: gentx delegator_address empty, denom order, EVM chain-id verification

Status: open
Owner: chain-core
Created: 2025-10-16
Related: docs/plans/runbooks/DEVNET_REGENESIS_RUNBOOK.md, scripts/quick_regenesis_766999.sh, scripts/create_genesis_accounts.sh

## Summary
During the devnet regenesis execution (target EVM chain ID 766999 / 0xBB417), the Genesis node fails to start due to invalid gentx contents and initial denom mismatches. We need to fix gentx generation and confirm the correct EVM chain-id param to complete regenesis.

## Environment
- Nodes: Genesis 52.9.17.25, Guardian 50.18.34.12, Nexus 204.236.162.240 (Ubuntu 24.04.2 LTS)
- florad: rebuilt and installed at /usr/local/bin/florad on all nodes
- Keyring backend: test (devnet)
- Cosmos chain-id: flora_7668378-1
- Target EVM chain-id: 766999 (0xBB417)

## What we attempted
- Deployed updated binary + scripts to all nodes
- Validators: ROLE=validator quick_regenesis to init, mint 10M, gentx 1M
- Lead: created faucet/dev pool accounts, added validator balances, set EVM chain-id in genesis, attempted collect-gentxs, distributed genesis, configured peers, and started services

## Observed failures (evidence)
1) Gentx missing delegator addresses
- All gentx files contain `"delegator_address": ""`.
- Example (Genesis gentx):
```
"messages":[{"@type":"/cosmos.staking.v1beta1.MsgCreateValidator", ..., "delegator_address":"", "validator_address":"floravaloper1...", "value":{"denom":"uflora","amount":"1000000000000000000000000"}}]
```
- collect-gentxs error: `failed to get genesis app state from config: account <delegator> balance not in genesis state`
- InitChain panic: `invalid coin denomination: got uflora, expected stake` (initially), later still fails due to gentx with empty delegator.

2) Denom mismatch at first start
- Staking default bond_denom is `stake` while gentx used `uflora`.
- We patched genesis to set `staking.params.bond_denom = uflora`, `mint.params.mint_denom = uflora`, `crisis.constant_fee.denom = uflora`, `evm.params.evm_denom = uflora` — but startup still fails because of invalid gentx.

3) EVM chain-id runtime check
- Non-lead nodes returned `0x75029a` (net id) in early checks while not producing blocks; cannot validate 0xBB417 until chain starts. Need to confirm the correct genesis param path for eth_chainId in this app.

## Impact
- Devnet currently not producing blocks after reset; regenesis incomplete.
- Cannot proceed until gentx contains valid delegator addresses and the denom is set before gentx collection.

## Hypotheses
- H1: florad `genesis gentx` is not populating `delegator_address` when using `eth_secp256k1` keys (cosmos-evm); requires code fix.
- H2: Denom `bond_denom` must be set to `uflora` in genesis BEFORE running gentx/collect; current scripts set denoms too late.
- H3: EVM chain-id should be set at `.app_state.evm.params.chain_config.chain_id`, but the app may derive eth_chainId differently until height > 0.

## Proposed fixes (Option A selected)
- F1: Use stock gentx with the correct flags/context (no application code changes): ensure `--from validator --keyring-backend test` is passed and the `validator` key exists.
- F2: Set all denom fields in genesis immediately after `init`, before running any `gentx`/`collect`.
- F3: Enable EIP‑155 at genesis: set `.app_state.evm.params.chain_config.eip155_block = "0"` (and chain_id=`766999`).
- F4: Add a 9M reserve account to reach exactly 50M supply.

## Data to collect (next)
- florad version details (`florad version -long`) and module versions on Genesis.
- App code references for: staking bond_denom default, gentx CLI path, evm.params.chain_config usage.
- Minimal reproduction: local `init` + set denoms + `keys add` + `genesis gentx` + inspect gentx JSON.

## Execution plan (proposed)
1) Investigate/validate (no code changes)
- [x] Validate gentx behavior with `--from` and `--keyring-backend test` after denoms are set.
2) Adjust scripts
- [x] Update quick_regenesis_766999.sh to set all denoms pre-gentx, set eip155_block="0" at genesis, and sanity‑gate gentx files. (See scripts/quick_regenesis_766999.sh and deployment/scripts/quick_regenesis_766999.sh)
3) Re-run regenesis (EIP‑155 polish, ~30m)
- [ ] Guardian/Nexus: ROLE=validator -> new gentx
- [ ] Genesis: ROLE=lead -> set eip155_block="0", collect-gentxs, validate, distribute
- [ ] Start all; verify eth_chainId 0xBB417, peers=2, blocks > 0; supply = 50M

## Attempt log — 2025-10-16

What we did
- Used correct SSH key: `~/.ssh/esprezzo/norcal-pub.pem` to access all three nodes.
- Ran the Option A polish: init with `flora_7668378-1`, set all denoms=uflora pre‑gentx, set `.app_state.evm.params.chain_config = { chain_id: "766999", eip155_block: "0" }`, minted allocations to total 50M, collected gentx, validated genesis, enabled JSON‑RPC/REST, configured peers.

**CRITICAL DISCOVERY (Oct 16, 08:45 UTC)**
- **Empty delegator_address is NOT the actual problem!**
- Checked old working gentx from July 2025 backup: `~/.flora.backup-20250725-180306/config/gentx/gentx-448ba973f8513215f556420cb779f749afe631d3.json`
- **This old working gentx ALSO has empty delegator_address: ""**
- The chain successfully ran for months with empty delegator_address fields in gentx

Observed failures (with exact errors)
1) gentx delegator_address empty on multiple runs
   - `"delegator_address": ""` in all gentx files produced by `florad genesis gentx ...` even when passing `--from validator --keyring-backend test`.
   - **UPDATE**: This has always been the case and is NOT the root cause.
2) After JSON repair with repair_gentx.sh, signature rejected at InitGenesis
   - The repair_gentx.sh script successfully populated delegator_address fields
   - Current state on nodes: All gentx files have delegator_address populated
   - BUT: Panic during `InitGenesis`: `signature verification failed; please verify account number (0) and chain-id (flora_7668378-1): unauthorized` — node exits before height 1.
   - **This is the actual problem**: Manual JSON edits invalidate the signature
3) Validator set empty after collect-gentxs
   - Error: `error on replay: validator set is empty after InitGenesis, please ensure at least one validator is initialized with a delegation greater than or equal to the DefaultPowerReduction ({824644621472})`
   - Our amounts (1000000000000000000000000) are much greater than DefaultPowerReduction
   - The signatures are being rejected due to the manual edits
4) Config gotcha: gRPC vs REST address
   - Setting `address = "tcp://0.0.0.0:1317"` under `[grpc]` triggers: `invalid grpc address tcp://0.0.0.0:1317`. Correct is `[grpc] address = "0.0.0.0:9090"`. REST remains at `tcp://0.0.0.0:1317` under the API section when present.

Analysis (UPDATED)
- The `florad genesis gentx` command has ALWAYS produced empty `delegator_address` for self-delegation. This is not new and not the root cause.
- The chain previously worked fine with empty delegator_address in gentx files.
- When we manually repair the JSON with repair_gentx.sh to add delegator_address, the signature no longer matches and genesis verification fails.
- Re-signing modified gentx fails with "tx intended signer does not match the given signer" - the signing context doesn't match the modified transaction.
- **The actual issue appears to be that we cannot start from the repaired gentx files due to invalid signatures.**

Two clean ways forward
- A1 (use empty delegator_address as before): Start fresh regenesis WITHOUT repair_gentx.sh, let delegator_address remain empty as it always has been. The chain should start as it did before.
- A2 (deterministic JSON injection, no gentx): Skip gentx entirely and inject the initial validator set + self‑delegations directly into `staking.validators` and `staking.delegations` in genesis. This ensures correct structure without signature issues.

Acceptance criteria (unchanged)
- `collect-gentxs` or injected set produces a valid genesis with ≥1 validator and power ≥ DefaultPowerReduction.
- Nodes start, produce blocks, peers=2.
- `eth_chainId` returns `0xBB417` on all nodes; `florad query evm params` shows `chain_id=766999`.
- REST `/cosmos/base/tendermint/v1beta1/node_info` returns `flora_7668378-1`.

Handoff checklist for next agent
- Confirm `florad version` on all nodes; use a build known to produce valid gentx with non‑empty `delegator_address`.
- If proceeding with A2, use a scripted validator injection and keep the 50M bank allocations identical to the plan.
- Re‑enable JSON‑RPC/REST; ensure `[grpc] address = "0.0.0.0:9090"` (do not point `[grpc]` at 1317).

## Acceptance criteria
- collect-gentxs succeeds without errors
- Genesis node starts; network produces blocks
- eth_chainId returns 0xBB417 on all nodes
- Total supply: 50,000,000 FLORA; per-allocations present

## Roll-forward/rollback
- Roll-forward: apply patch + re-run regenesis as above
- Rollback: no prior chain state retained (devnet); quickest path back is to complete regenesis

## Attachments (snippets)
- InitChain panic: `invalid coin denomination: got uflora, expected stake`
- gentx excerpt showing `delegator_address: ""`
- Latest genesis SHA256 on Genesis `531eddf43c...952f`
