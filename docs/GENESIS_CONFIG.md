# Flora Genesis Configuration Guide

## Overview

The genesis file is the initial configuration that bootstraps a Flora blockchain network. It defines the initial state, parameters, accounts, and validators at block height 0. This guide covers all aspects of configuring genesis for Flora networks.

## Table of Contents

- [Genesis Structure](#genesis-structure)
- [Chain Configuration](#chain-configuration)
- [Module Parameters](#module-parameters)
- [Account Setup](#account-setup)
- [Validator Configuration](#validator-configuration)
- [Token Distribution](#token-distribution)
- [Network Examples](#network-examples)
- [Tools and Scripts](#tools-and-scripts)

## Security and Config Generation

Important: Hard-coded mnemonics and addresses have been removed from repo configs. Use the example templates and the generator script to produce concrete, local-only configs.

- Example templates:
  - chains/standalone.example.json
  - chains/self-ibc.example.json
  - chains/testnet.example.json
- Generator script:
  - scripts/generate_chain_config.sh

What this does:
- Derives addresses from provided mnemonics or generates new dev mnemonics using florad
- Renders real configs into chains/generated/
- Writes chains/generated/addresses.env and chains/generated/addresses.json with any generated mnemonics and derived addresses
- chains/generated/ is ignored by git

Quick usage:
```bash
# Standalone local config
scripts/generate_chain_config.sh -t standalone

# Self-IBC config for two local chains
scripts/generate_chain_config.sh -t self-ibc

# Testnet with a Gaia peer chain (provide Gaia addrs if you want to replace placeholders)
GAIA_ACC0_ADDRESS="cosmos1..." GAIA_ACC1_ADDRESS="cosmos1..." \
  scripts/generate_chain_config.sh -t testnet
```

Environment inputs (optional):
- ACC0_MNEMONIC, ACC1_MNEMONIC, USER0_MNEMONIC, USER1_MNEMONIC
- For self-ibc second chain: ACC0_MNEMONIC_2, ACC1_MNEMONIC_2, USER0_MNEMONIC_2, USER1_MNEMONIC_2
- Chain ID overrides: CHAIN_ID and, for self-ibc, CHAIN_ID_2

Output:
- chains/generated/&lt;template&gt;.json
- chains/generated/addresses.env, chains/generated/addresses.json

Do not commit:
- Any generated mnemonics or addresses files. These are intentionally git-ignored.
- Deterministic test mnemonics are kept only in interchaintest for automated tests; never use them for any public or persistent network.

Notes on Chain IDs:
- Example templates default to flora_766999-1 style IDs for devnet consistency
- You can override via CHAIN_ID (and CHAIN_ID_2 for self-ibc)
## Genesis Structure

### Basic Structure
```json
{
  "genesis_time": "2024-01-01T00:00:00Z",
  "chain_id": "flora_766999-1",
  "initial_height": "1",
  "consensus_params": {...},
  "app_hash": "",
  "app_state": {...}
}
```

### Key Components
- **genesis_time**: Network start time (ISO 8601 format)
- **chain_id**: Unique identifier for the chain
- **initial_height**: Starting block height (usually 1)
- **consensus_params**: Consensus layer parameters
- **app_state**: Application state including all module configurations

## Chain Configuration

### Chain ID Format
Flora uses EVM-compatible chain IDs:
```
Format: {identifier}_{evm-chain-id}-{version}
Example: flora_766999-1
```

- **identifier**: Chain name (flora)
- **evm-chain-id**: EVM chain ID (766999 (0xBB417))
- **version**: Version number for upgrades

### Consensus Parameters
```json
{
  "consensus_params": {
    "block": {
      "max_bytes": "22020096",
      "max_gas": "100000000",
      "time_iota_ms": "1000"
    },
    "evidence": {
      "max_age_num_blocks": "100000",
      "max_age_duration": "172800000000000",
      "max_bytes": "1048576"
    },
    "validator": {
      "pub_key_types": ["ed25519"]
    },
    "version": {
      "app_version": "0"
    },
    "abci": {
      "vote_extensions_enable_height": "1"
    }
  }
}
```

## Module Parameters

### Bank Module
```json
{
  "bank": {
    "params": {
      "send_enabled": [],
      "default_send_enabled": true
    },
    "balances": [...],
    "supply": [...],
    "denom_metadata": [
      {
        "description": "The native token of Flora",
        "denom_units": [
          {
            "denom": "uflora",
            "exponent": 0,
            "aliases": ["microflora"]
          },
          {
            "denom": "flora",
            "exponent": 18,
            "aliases": ["FLORA"]
          }
        ],
        "base": "uflora",
        "display": "flora",
        "name": "Flora",
        "symbol": "FLORA"
      }
    ]
  }
}
```

### Staking Module
```json
{
  "staking": {
    "params": {
      "unbonding_time": "1814400s",
      "max_validators": 100,
      "max_entries": 7,
      "historical_entries": 10000,
      "bond_denom": "uflora",
      "min_commission_rate": "0.050000000000000000"
    },
    "last_total_power": "0",
    "validators": [...],
    "delegations": [...]
  }
}
```

### Governance Module
```json
{
  "gov": {
    "params": {
      "min_deposit": [
        {
          "denom": "uflora",
          "amount": "1000000000"
        }
      ],
      "max_deposit_period": "172800s",
      "voting_period": "259200s",
      "quorum": "0.334000000000000000",
      "threshold": "0.500000000000000000",
      "veto_threshold": "0.334000000000000000",
      "min_initial_deposit_ratio": "0.100000000000000000",
      "expedited_voting_period": "86400s",
      "expedited_threshold": "0.667000000000000000",
      "expedited_min_deposit": [
        {
          "denom": "uflora",
          "amount": "5000000000"
        }
      ]
    }
  }
}
```

### Distribution Module
```json
{
  "distribution": {
    "params": {
      "community_tax": "0.020000000000000000",
      "base_proposer_reward": "0.010000000000000000",
      "bonus_proposer_reward": "0.040000000000000000",
      "withdraw_addr_enabled": true
    },
    "fee_pool": {
      "community_pool": []
    },
    "delegator_withdraw_infos": [],
    "previous_proposer": "",
    "outstanding_rewards": [],
    "validator_accumulated_commissions": [],
    "validator_historical_rewards": [],
    "validator_current_rewards": [],
    "delegator_starting_infos": [],
    "validator_slash_events": []
  }
}
```

### Mint Module
```json
{
  "mint": {
    "minter": {
      "inflation": "0.130000000000000000",
      "annual_provisions": "0.000000000000000000"
    },
    "params": {
      "mint_denom": "uflora",
      "inflation_rate_change": "0.130000000000000000",
      "inflation_max": "0.200000000000000000",
      "inflation_min": "0.070000000000000000",
      "goal_bonded": "0.670000000000000000",
      "blocks_per_year": "6311520"
    }
  }
}
```

### EVM Module
```json
{
  "evm": {
    "params": {
      "evm_denom": "uflora",
      "enable_create": true,
      "enable_call": true,
      "extra_eips": [],
      "chain_config": {
        "homestead_block": "0",
        "dao_fork_block": "0",
        "dao_fork_support": true,
        "eip150_block": "0",
        "eip150_hash": "0x0000000000000000000000000000000000000000000000000000000000000000",
        "eip155_block": "0",
        "eip158_block": "0",
        "byzantium_block": "0",
        "constantinople_block": "0",
        "petersburg_block": "0",
        "istanbul_block": "0",
        "muir_glacier_block": "0",
        "berlin_block": "0",
        "london_block": "0",
        "arrow_glacier_block": "0",
        "gray_glacier_block": "0",
        "merge_netsplit_block": "0",
        "shanghai_block": "0",
        "cancun_block": "0"
      },
      "allow_unprotected_txs": false,
      "active_static_precompiles": [
        "0x0000000000000000000000000000000000000100",
        "0x0000000000000000000000000000000000000400",
        "0x0000000000000000000000000000000000000800",
        "0x0000000000000000000000000000000000000801",
        "0x0000000000000000000000000000000000000802",
        "0x0000000000000000000000000000000000000803",
        "0x0000000000000000000000000000000000000804",
        "0x0000000000000000000000000000000000000805"
      ]
    }
  }
}
```

### Fee Market Module
```json
{
  "feemarket": {
    "params": {
      "no_base_fee": false,
      "base_fee_change_denominator": 8,
      "elasticity_multiplier": 2,
      "enable_height": "0",
      "base_fee": "1000000000",
      "min_gas_price": "0.000000001",
      "min_gas_multiplier": "0.5"
    },
    "block_gas": "0"
  }
}
```

### Token Factory Module
```json
{
  "tokenfactory": {
    "params": {
      "denom_creation_fee": [
        {
          "denom": "uflora",
          "amount": "10000000"
        }
      ],
      "denom_creation_gas_consume": 100000
    },
    "factory_denoms": []
  }
}
```

### IBC Module
```json
{
  "ibc": {
    "client_genesis": {
      "clients": [],
      "clients_consensus": [],
      "clients_metadata": [],
      "params": {
        "allowed_clients": ["06-solomachine", "07-tendermint"]
      },
      "create_localhost": false,
      "next_client_sequence": "0"
    },
    "connection_genesis": {
      "connections": [],
      "client_connection_paths": [],
      "next_connection_sequence": "0",
      "params": {
        "max_expected_time_per_block": "30000000000"
      }
    },
    "channel_genesis": {
      "channels": [],
      "acknowledgements": [],
      "commitments": [],
      "receipts": [],
      "send_sequences": [],
      "recv_sequences": [],
      "ack_sequences": [],
      "next_channel_sequence": "0"
    }
  }
}
```

## Account Setup

### Genesis Accounts
```bash
# Add a genesis account
florad add-genesis-account flora1... 1000000000uflora

# Add account with vesting
florad add-genesis-account flora1... 1000000000uflora \
  --vesting-amount 500000000uflora \
  --vesting-end-time 1735689600 \
  --vesting-start-time 1704067200
```

### Account Structure
```json
{
  "app_state": {
    "auth": {
      "accounts": [
        {
          "@type": "/cosmos.auth.v1beta1.BaseAccount",
          "address": "flora1...",
          "pub_key": null,
          "account_number": "0",
          "sequence": "0"
        },
        {
          "@type": "/cosmos.vesting.v1beta1.ContinuousVestingAccount",
          "base_vesting_account": {
            "base_account": {
              "address": "flora1...",
              "pub_key": null,
              "account_number": "1",
              "sequence": "0"
            },
            "original_vesting": [
              {
                "denom": "uflora",
                "amount": "500000000"
              }
            ],
            "delegated_free": [],
            "delegated_vesting": [],
            "end_time": "1735689600"
          },
          "start_time": "1704067200"
        }
      ]
    }
  }
}
```

## Validator Configuration

### Add Genesis Validator
```bash
# Generate validator transaction
florad gentx validator-key 100000000uflora \
  --chain-id flora_766999-1 \
  --moniker="Validator-1" \
  --commission-max-change-rate="0.01" \
  --commission-max-rate="0.20" \
  --commission-rate="0.10" \
  --min-self-delegation="1" \
  --details="Genesis validator" \
  --website="https://validator.flora.network"

# Collect genesis transactions
florad collect-gentxs
```

### Validator Genesis Structure
```json
{
  "app_state": {
    "genutil": {
      "gen_txs": [
        {
          "body": {
            "messages": [
              {
                "@type": "/cosmos.staking.v1beta1.MsgCreateValidator",
                "description": {
                  "moniker": "Validator-1",
                  "identity": "",
                  "website": "https://validator.flora.network",
                  "security_contact": "",
                  "details": "Genesis validator"
                },
                "commission": {
                  "rate": "0.100000000000000000",
                  "max_rate": "0.200000000000000000",
                  "max_change_rate": "0.010000000000000000"
                },
                "min_self_delegation": "1",
                "delegator_address": "flora1...",
                "validator_address": "floravaloper1...",
                "pubkey": {
                  "@type": "/cosmos.crypto.ed25519.PubKey",
                  "key": "..."
                },
                "value": {
                  "denom": "uflora",
                  "amount": "100000000"
                }
              }
            ]
          }
        }
      ]
    }
  }
}
```

## Token Distribution

### Initial Supply Allocation
```json
{
  "app_state": {
    "bank": {
      "supply": [
        {
          "denom": "uflora",
          "amount": "1000000000000000"
        }
      ],
      "balances": [
        {
          "address": "flora1...",
          "coins": [
            {
              "denom": "uflora",
              "amount": "100000000000000"
            }
          ]
        }
      ]
    }
  }
}
```

### Distribution Strategy Example
| Category | Percentage | Amount (uflora) | Vesting |
|----------|------------|-----------------|---------|
| Team | 20% | 200000000000000 | 4 years |
| Foundation | 15% | 150000000000000 | 2 years |
| Community | 30% | 300000000000000 | None |
| Validators | 10% | 100000000000000 | None |
| Ecosystem | 25% | 250000000000000 | 1 year |

## Network Examples

### Mainnet Configuration
```json
{
  "genesis_time": "2024-06-01T00:00:00Z",
  "chain_id": "flora_766999-1",
  "consensus_params": {
    "block": {
      "max_gas": "100000000"
    }
  },
  "app_state": {
    "gov": {
      "params": {
        "voting_period": "1209600s",
        "min_deposit": [{
          "denom": "uflora",
          "amount": "10000000000"
        }]
      }
    },
    "staking": {
      "params": {
        "unbonding_time": "2419200s",
        "max_validators": 125
      }
    }
  }
}
```

### Testnet Configuration
```json
{
  "genesis_time": "2024-01-01T00:00:00Z",
  "chain_id": "flora_766999-1",
  "consensus_params": {
    "block": {
      "max_gas": "100000000"
    }
  },
  "app_state": {
    "gov": {
      "params": {
        "voting_period": "30s",
        "min_deposit": [{
          "denom": "uflora",
          "amount": "1000000"
        }]
      }
    },
    "staking": {
      "params": {
        "unbonding_time": "300s",
        "max_validators": 10
      }
    },
    "feemarket": {
      "params": {
        "no_base_fee": true,
        "base_fee": "0"
      }
    }
  }
}
```

### Local Development
```json
{
  "genesis_time": "2024-01-01T00:00:00Z",
  "chain_id": "localflora_9000-1",
  "consensus_params": {
    "block": {
      "max_gas": "100000000",
      "time_iota_ms": "100"
    }
  },
  "app_state": {
    "gov": {
      "params": {
        "voting_period": "10s"
      }
    },
    "staking": {
      "params": {
        "unbonding_time": "60s"
      }
    },
    "tokenfactory": {
      "params": {
        "denom_creation_fee": []
      }
    }
  }
}
```

## Tools and Scripts

### Genesis Manipulation Script
```bash
#!/bin/bash
# update_genesis.sh

update_genesis() {
  cat $HOME/.florad/config/genesis.json | \
    jq "$1" > $HOME/.florad/config/tmp_genesis.json && \
    mv $HOME/.florad/config/tmp_genesis.json $HOME/.florad/config/genesis.json
}

# Set chain parameters
update_genesis '.chain_id="flora_766999-1"'
update_genesis '.consensus_params["block"]["max_gas"]="100000000"'

# Configure modules
update_genesis '.app_state["staking"]["params"]["bond_denom"]="uflora"'
update_genesis '.app_state["mint"]["params"]["mint_denom"]="uflora"'
update_genesis '.app_state["evm"]["params"]["evm_denom"]="uflora"'
update_genesis '.app_state["gov"]["params"]["min_deposit"]=[{"denom":"uflora","amount":"1000000"}]'

# Set gas prices
update_genesis '.app_state["feemarket"]["params"]["base_fee"]="1000000000"'
update_genesis '.app_state["feemarket"]["params"]["no_base_fee"]=false'

# Configure EVM
update_genesis '.app_state["evm"]["params"]["chain_config"]["chain_id"]="7668378"'

echo "Genesis configuration updated successfully"
```

### Validator Setup Script
```bash
#!/bin/bash
# setup_validator.sh

CHAIN_ID="flora_766999-1"
MONIKER="my-validator"
AMOUNT="100000000uflora"

# Initialize node
florad init $MONIKER --chain-id $CHAIN_ID

# Add genesis account
florad keys add validator --keyring-backend test
VALIDATOR_ADDR=$(florad keys show validator -a --keyring-backend test)
florad add-genesis-account $VALIDATOR_ADDR 1000000000uflora

# Create genesis transaction
florad gentx validator $AMOUNT \
  --chain-id $CHAIN_ID \
  --moniker $MONIKER \
  --commission-rate="0.10" \
  --commission-max-rate="0.20" \
  --commission-max-change-rate="0.01" \
  --min-self-delegation="1" \
  --keyring-backend test

# Collect genesis transactions
florad collect-gentxs

echo "Validator setup complete"
```

### Genesis Validation
```bash
# Validate genesis file
florad genesis validate

# Check specific module genesis
florad query auth genesis-state
florad query bank genesis-state
florad query staking genesis-state

# Export current state as genesis
florad export > exported_genesis.json
```

## Common Genesis Issues

### Problem: Chain Won't Start
**Solution**: Check these common issues:
```bash
# Validate genesis syntax
jq . genesis.json > /dev/null

# Check chain ID format
grep chain_id genesis.json

# Verify initial height
grep initial_height genesis.json

# Check validator has enough stake
jq '.app_state.genutil.gen_txs[].body.messages[0].value' genesis.json
```

### Problem: EVM Chain ID Mismatch
**Solution**: Ensure consistency:
```bash
# Chain ID should match pattern
CHAIN_ID="flora_766999-1"  # 766999 is EVM chain ID

# Update EVM config
jq '.app_state.evm.params.chain_config.chain_id = "766999"' genesis.json
```

### Problem: Insufficient Validator Stake
**Solution**: Ensure validators meet minimum requirements:
```bash
# Check minimum self-delegation
MIN_STAKE="1000000uflora"

# Update validator stake
florad gentx validator $MIN_STAKE --chain-id $CHAIN_ID
```

### Problem: Token Supply Mismatch
**Solution**: Ensure supply equals sum of balances:
```bash
# Calculate total from balances
jq '[.app_state.bank.balances[].coins[].amount | tonumber] | add' genesis.json

# Update supply
jq '.app_state.bank.supply[0].amount = "TOTAL_AMOUNT"' genesis.json
```

## Best Practices

1. **Version Control**: Always version control your genesis files
2. **Backup**: Keep backups before making changes
3. **Validation**: Always validate after changes
4. **Documentation**: Document all parameter choices
5. **Testing**: Test genesis on a local network first
6. **Security**: Never expose validator keys in genesis
7. **Determinism**: Use consistent timestamps for coordinated launches
8. **Parameters**: Start with conservative parameters, adjust gradually
9. **Distribution**: Plan token distribution carefully
10. **Upgrades**: Plan for future chain upgrades in chain ID

## Migration and Upgrades

### Export State for Migration
```bash
# Stop the chain at specific height
florad export --height 1000000 > export_1000000.json

# Process exported state
python3 migrate_genesis.py export_1000000.json > new_genesis.json

# Start new chain with migrated state
florad start --genesis new_genesis.json
```

### Chain ID Versioning
```
Initial: flora_766999-1
Upgrade: flora_7668378-2
Major:   flora_7668379-1
```

## Resources

- [Cosmos SDK Genesis Documentation](https://docs.cosmos.network/main/basics/genesis)
- [Tendermint Genesis Format](https://docs.tendermint.com/master/tendermint-core/using-tendermint.html#genesis)
- [EVM Chain Configuration](https://docs.evmos.org/protocol/concepts/chain-id)
- [Flora Network Documentation](https://docs.flora.network)
