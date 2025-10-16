# Plans Backlog (chain_build/flora)

## Strategy Documents
- **CHAIN_ID_STRATEGY** (`docs/CHAIN_ID_STRATEGY.md`) — Complete chain ID architecture for devnet/mainnet separation. Devnet: 766999 (0xBB417), Mainnet: 766793 (0xBB349)
- **DEVNET_REGENESIS_RUNBOOK** (`docs/plans/runbooks/DEVNET_REGENESIS_RUNBOOK.md`) — Single, step-by-step execution guide for the devnet regenesis using the role-based scripts
- **Issue 0005** (`docs/plans/issues/0005-devnet-regenesis-blockers.md`) — Tracking current blockers (gentx delegator empty, denom order, eth_chainId verification)

## Active Tasks
- 0001-runbook-evm-chainid-renumbering-regenesis — Full procedure to change the EVM chainId and perform a devnet regenesis with minimal downtime. Uses chain ID 766999 for devnet.
- 0002-task-update-clients-to-new-chainid — Update web/app/scripts/tests and internal docs to the new chainId (766999 for devnet).
- 0003-devnet-genesis-regenesis-plan — Complete genesis configuration with validator allocations, token distribution, and coordinated genesis script for all 3 validators.
- 0004-code-deployment-regenesis — Binary build and deployment plan to get updated code to all three validator nodes. Includes scripts for backup, deployment, and verification.
