# Plans Backlog (chain_build/flora)

## Strategy Documents
- **CHAIN_ID_STRATEGY** (`docs/CHAIN_ID_STRATEGY.md`) — Complete chain ID architecture for devnet/mainnet separation. Devnet: 766999 (0xbb3e7), Mainnet: 766793 (0xbb349)

## Active Tasks
- 0001-runbook-evm-chainid-renumbering-regenesis — Full procedure to change the EVM chainId and perform a devnet regenesis with minimal downtime. Uses chain ID 766999 for devnet.
- 0002-task-update-clients-to-new-chainid — Update web/app/scripts/tests and internal docs to the new chainId (766999 for devnet).
- 0003-devnet-genesis-regenesis-plan — Complete genesis configuration with validator allocations, token distribution, and coordinated genesis script for all 3 validators.
- 0004-code-deployment-regenesis — Binary build and deployment plan to get updated code to all three validator nodes. Includes scripts for backup, deployment, and verification.
