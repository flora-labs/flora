# Flora Network Chain ID Strategy

**Status**: Approved  
**Version**: 1.0  
**Date**: 2025-10-15  
**Owner**: Chain Core Team

## Executive Summary

Flora Network uses a dual chain ID strategy to distinguish between development/testing environments and production mainnet while maintaining brand consistency through FLORA-encoded numeric patterns.

## Chain ID Assignments

### Devnet (Current Priority)
```
Chain ID: 766999 (0xbb3e7)
Network Name: Flora Devnet
Purpose: Development and testing
Status: Approved for immediate deployment
```

**Rationale**:
- `766` = FLORA base numeric encoding
- `999` = Clear testnet/development indicator
- Verified unique on chainlist.org and chainid.network
- Eliminates Evmos collision (9000) warnings in MetaMask
- Disposable for regenesis during development cycles

### Mainnet (Reserved)
```
Chain ID: 766793 (0xbb349)
Network Name: Flora Network
Purpose: Production blockchain
Status: Reserved for mainnet launch
```

**Rationale**:
- `766793` = Full FLORA numeric encoding
- Premium/canonical chain ID for production
- Clean, memorable, and brandable
- Zero conflicts with existing networks

## Problem Statement

### Historical Issues

**Original Configuration**:
- Cosmos Chain ID: `flora_7668378-1`
- Intended EVM Chain ID: `7668378` (0x75029a)
- **Problem**: QL1 Testnet already uses 7668378

**Current Configuration** (Pre-Regenesis):
- EVM Chain ID: `9000` (0x2328)
- **Problem**: Evmos Testnet uses 9000, causing MetaMask warnings

### Requirements

1. **Uniqueness**: Must not conflict with existing chain registries
2. **Brand Alignment**: Should encode or reference "FLORA"
3. **Environment Distinction**: Clear separation between devnet and mainnet
4. **MetaMask Compatibility**: Zero network mismatch warnings
5. **Future-Proof**: Support for additional testnets if needed

## Chain ID Selection Process

### Verification Steps

For each candidate chain ID:
1. Search `site:chainlist.org <CHAIN_ID>`
2. Search `site:chainid.network <CHAIN_ID>`
3. Check ethereum-lists/chains GitHub repository
4. Verify hex conversion: `printf "0x%x\n" <DECIMAL>`

### Evaluation Criteria

| Criteria | Weight | Devnet (766999) | Mainnet (766793) |
|----------|--------|-----------------|------------------|
| Uniqueness | HIGH | ✅ Verified | ✅ Verified |
| FLORA Encoding | MEDIUM | ✅ Partial (766) | ✅ Full |
| Memorability | MEDIUM | ✅ Good | ✅ Excellent |
| Brand Value | LOW | ⚠️ Testnet | ✅ Premium |
| Conflict-Free | HIGH | ✅ Yes | ✅ Yes |

## Architecture

### Network Hierarchy

```
Flora Ecosystem
│
├── Devnet (766999 / 0xbb3e7)
│   ├── Purpose: Active development and testing
│   ├── Stability: Subject to frequent resets/regenesis
│   ├── Access: Public for developers
│   └── Lifecycle: Continuous until mainnet launch
│
├── Testnet (Future)
│   ├── Purpose: Pre-production testing
│   ├── Candidate ID: 766998 (0xbb3e6)
│   └── Status: Not yet deployed
│
└── Mainnet (766793 / 0xbb349)
    ├── Purpose: Production blockchain
    ├── Stability: Permanent, no regenesis
    ├── Access: Public
    └── Launch: TBD (Q2 2025+)
```

### Cosmos vs EVM Chain ID

**Important Distinction**:
- **Cosmos Chain ID**: `flora_7668378-1` (remains constant across all environments)
- **EVM Chain ID**: Environment-specific (766999 for devnet, 766793 for mainnet)

The Cosmos chain ID format `flora_NNNNNN-R` where:
- `flora` = Network identifier
- `NNNNNN` = Original reference number
- `R` = Revision number

The EVM chain ID is what MetaMask and Web3 wallets use for transaction signing (EIP-155).

## Implementation Timeline

### Phase 1: Devnet Regenesis (Current)
- [ ] Update genesis configuration with EVM chain ID 766999
- [ ] Perform controlled devnet regenesis
- [ ] Update RPC endpoints and documentation
- [ ] Test MetaMask connectivity (expect zero warnings)
- [ ] Update client applications and scripts

**Timeline**: 60-90 minute maintenance window  
**Runbook**: `docs/plans/todo/0001-runbook-evm-chainid-renumbering-regenesis.md`

### Phase 2: Public Testnet (Future)
- [ ] Deploy dedicated testnet with chain ID 766998
- [ ] Establish testnet faucet and block explorer
- [ ] Community testing period

**Timeline**: Pre-mainnet (3-6 months before launch)

### Phase 3: Mainnet Launch (Reserved)
- [ ] Genesis ceremony with chain ID 766793
- [ ] Production RPC infrastructure (`rpc.flora.network`)
- [ ] Mainnet block explorer
- [ ] Official launch announcements

**Timeline**: TBD based on development milestones

## Migration Path

### From Current State (9000) to Devnet (766999)

**User Impact**:
- Users must remove old network from MetaMask
- Re-add Flora Devnet with new chain ID 766999
- All previous testnet balances/state will be reset

**Client Updates Required**:
- Web applications: Update chain ID constants
- Scripts: Replace references to 9000 → 766999
- Tests: Update mock chain ID responses
- Documentation: Update all configuration examples

**See**: `docs/plans/todo/0002-task-update-clients-to-new-chainid.md`

### From Devnet (766999) to Mainnet (766793)

**User Impact**:
- New network addition in MetaMask
- Devnet and mainnet will coexist
- No migration of devnet assets to mainnet

**Client Updates Required**:
- Add mainnet configuration alongside devnet
- Implement network switcher in UIs
- Update default network selection logic

## Chain ID Numbering Convention

### FLORA Encoding

The base pattern `766` derives from:
- Alphabetic position encoding of "FLORA"
- Memorable and brandable
- Sufficient uniqueness when extended

### Suffix Strategy

| Suffix | Purpose | Example |
|--------|---------|---------|
| 793 | Mainnet (premium encoding) | 766793 |
| 999 | Devnet (test indicator) | 766999 |
| 998 | Public testnet | 766998 |
| 997 | Staging (if needed) | 766997 |
| 900-989 | Reserved for future environments | TBD |

## MetaMask Configuration

### Devnet (766999)
```javascript
const FLORA_DEVNET_CONFIG = {
  chainId: '0xbb3e7',  // 766999 in decimal
  chainName: 'Flora Devnet',
  nativeCurrency: {
    name: 'FLORA',
    symbol: 'FLORA',
    decimals: 18
  },
  rpcUrls: ['https://rpc.devnet.flora.network'],
  blockExplorerUrls: ['https://explorer.devnet.flora.network']
};
```

### Mainnet (766793) - Reserved
```javascript
const FLORA_MAINNET_CONFIG = {
  chainId: '0xbb349',  // 766793 in decimal
  chainName: 'Flora Network',
  nativeCurrency: {
    name: 'FLORA',
    symbol: 'FLORA',
    decimals: 18
  },
  rpcUrls: ['https://rpc.flora.network'],
  blockExplorerUrls: ['https://explorer.flora.network']
};
```

## Rejected Alternatives

| Chain ID | Reason for Rejection |
|----------|---------------------|
| 7668378 (0x75029a) | Collision with QL1 Testnet |
| 9000 (0x2328) | Collision with Evmos Testnet |
| 9001 (0x2329) | Collision with Evmos Mainnet |
| 420420 (0x66ba4) | No FLORA brand connection |
| 76679 (0x12b87) | Good but less distinctive than 766999 |

## References

- [ChainList.org](https://chainlist.org/) - EVM chain registry
- [ChainID.network](https://chainid.network/) - Chain ID database
- [ethereum-lists/chains](https://github.com/ethereum-lists/chains) - Canonical chain metadata
- [EIP-155](https://eips.ethereum.org/EIPS/eip-155) - Simple replay attack protection

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2025-10-15 | Adopt dual chain ID strategy | Separate devnet from mainnet identity |
| 2025-10-15 | Devnet: 766999 (0xbb3e7) | FLORA-encoded + clear testnet indicator |
| 2025-10-15 | Mainnet: 766793 (0xbb349) | Reserve premium FLORA-encoded ID |
| 2025-10-15 | Deprecate 9000 | Evmos collision, UX degradation |

## Contact

For questions or changes to this strategy:
- Chain Core Team
- GitHub Issues: [flora-labs/flora](https://github.com/flora-labs/flora)
- Documentation: `docs/CHAIN_ID_STRATEGY.md`
