# Flora Gas and Fees Documentation

## Overview

Flora is an EVM-compatible Cosmos blockchain that implements a dual gas system supporting both Cosmos SDK transactions and Ethereum transactions. This document explains how gas and fees work across both execution environments.

## Table of Contents

- [Gas Concepts](#gas-concepts)
- [Fee Denomination](#fee-denomination)
- [Cosmos Transactions](#cosmos-transactions)
- [EVM Transactions](#evm-transactions)
- [Fee Market Module](#fee-market-module)
- [Gas Estimation](#gas-estimation)
- [Transaction Priority](#transaction-priority)
- [Developer Guidelines](#developer-guidelines)

## Gas Concepts

### Dual Gas System

Flora implements two gas metering systems:

1. **Cosmos SDK Gas**: Used for native Cosmos transactions
2. **EVM Gas**: Used for Ethereum transactions and smart contracts

Both systems ultimately consume the same underlying resource (computational effort) but use different units and pricing mechanisms.

### Gas Units

- **Cosmos Gas**: Abstract unit measuring computational complexity
- **EVM Gas**: Standard Ethereum gas units (21,000 for simple transfer)

## Fee Denomination

### Native Token
- **Symbol**: FLORA
- **Denomination**: `uflora` (micro-flora)
- **Decimals**: 18
- **EVM Representation**: `0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE`

### Fee Payment
All fees are paid in `uflora`, whether for Cosmos or EVM transactions.

## Cosmos Transactions

### Gas Pricing
```json
{
  "min_gas_price": "0.025uflora",
  "gas_wanted": 200000,
  "gas_used": 150000
}
```

### Fee Calculation
```
Fee = Gas * Gas Price
Example: 200,000 * 0.025uflora = 5,000uflora
```

### Setting Fees via CLI
```bash
# Set gas manually
florad tx bank send [from] [to] [amount] --gas=200000 --gas-prices=0.025uflora

# Use automatic gas estimation
florad tx bank send [from] [to] [amount] --gas=auto --gas-prices=0.025uflora

# Set gas adjustment for auto estimation
florad tx bank send [from] [to] [amount] --gas=auto --gas-adjustment=1.5 --gas-prices=0.025uflora
```

### Common Gas Costs
| Transaction Type | Typical Gas | Fee (at 0.025uflora) |
|-----------------|-------------|----------------------|
| Bank Send | 100,000 | 2,500uflora |
| Delegate | 250,000 | 6,250uflora |
| Vote | 80,000 | 2,000uflora |
| IBC Transfer | 150,000 | 3,750uflora |
| Token Factory Create | 1,000,000 | 25,000uflora |

## EVM Transactions

### Gas Pricing Model
Flora uses the Cosmos SDK `feemarket` module which implements EIP-1559-style dynamic gas pricing:

```json
{
  "base_fee": "1000000000",
  "priority_fee": "1000000000",
  "max_fee_per_gas": "10000000000",
  "max_priority_fee_per_gas": "1000000000"
}
```

### Fee Calculation
```
Total Fee = Gas Used * (Base Fee + Priority Fee)
Example: 21,000 * (1 gwei + 1 gwei) = 42,000 gwei
```

### Gas Limits
```json
{
  "block_gas_limit": 100000000,
  "default_gas_limit": 5000000,
  "min_gas_limit": 21000
}
```

### EVM Gas Costs
| Operation | Gas Cost |
|-----------|----------|
| Simple Transfer | 21,000 |
| ERC20 Transfer | ~65,000 |
| Deploy ERC20 | ~1,500,000 |
| Deploy NFT | ~2,500,000 |
| Swap (Uniswap-like) | ~150,000 |
| Storage Write | 20,000 per slot |
| Storage Read | 2,100 per slot |

### Setting Gas in Web3
```javascript
// Using ethers.js
const tx = {
  to: "0x...",
  value: ethers.parseEther("1.0"),
  gasLimit: 21000,
  maxFeePerGas: ethers.parseUnits("10", "gwei"),
  maxPriorityFeePerGas: ethers.parseUnits("1", "gwei")
};

// Using web3.js
const tx = {
  to: "0x...",
  value: web3.utils.toWei("1", "ether"),
  gas: 21000,
  gasPrice: web3.utils.toWei("10", "gwei")
};
```

## Fee Market Module

### Dynamic Base Fee
The base fee adjusts automatically based on block utilization:

```go
// Simplified algorithm
if blockGasUsed > targetGas {
    baseFee = baseFee * (1 + adjustmentFactor)
} else {
    baseFee = baseFee * (1 - adjustmentFactor)
}
```

### Configuration Parameters
```json
{
  "no_base_fee": false,
  "base_fee": "1000000000",
  "min_gas_price": "0.000000001",
  "elasticity_multiplier": 2,
  "enable_height": 0,
  "base_fee_change_denominator": 8,
  "min_gas_multiplier": "0.5"
}
```

### Disabling Base Fee
For development/testing, you can disable the base fee:
```json
{
  "no_base_fee": true,
  "base_fee": "0"
}
```

## Gas Estimation

### Cosmos SDK Transactions
```bash
# Simulate transaction to get gas estimate
florad tx bank send [from] [to] [amount] --dry-run

# Use auto gas with adjustment
florad tx bank send [from] [to] [amount] --gas=auto --gas-adjustment=1.3
```

### EVM Transactions
```javascript
// Estimate gas for a transaction
const estimatedGas = await provider.estimateGas({
  to: "0x...",
  data: "0x...",
  value: ethers.parseEther("1.0")
});

// Add 20% buffer
const gasLimit = estimatedGas * 120n / 100n;
```

### Best Practices for Gas Estimation
1. Always add a buffer (10-20%) to estimated gas
2. Monitor gas prices during high congestion
3. Use `eth_gasPrice` for current gas price
4. Implement retry logic with higher gas prices
5. Set reasonable timeout periods

## Transaction Priority

### Priority Levels
Transactions are prioritized based on fees:

1. **High Priority**: `priority_fee > base_fee * 2`
2. **Medium Priority**: `priority_fee > base_fee`
3. **Low Priority**: `priority_fee <= base_fee`

### Mempool Ordering
```
Priority Score = Gas Price * Gas Limit / Transaction Size
```

Higher scores get included in blocks first.

### Setting Priority
```javascript
// High priority transaction
const tx = {
  maxPriorityFeePerGas: ethers.parseUnits("5", "gwei"), // High tip
  maxFeePerGas: ethers.parseUnits("100", "gwei")
};

// Low priority transaction
const tx = {
  maxPriorityFeePerGas: ethers.parseUnits("0.1", "gwei"), // Low tip
  maxFeePerGas: ethers.parseUnits("10", "gwei")
};
```

## Developer Guidelines

### Optimizing Gas Usage

#### Cosmos SDK
1. Batch operations when possible
2. Use efficient data structures
3. Minimize state reads/writes
4. Avoid unnecessary iterations

#### EVM/Solidity
1. Pack struct variables
2. Use `calldata` instead of `memory`
3. Cache storage variables
4. Use events instead of storage for logs
5. Optimize loops and conditions

### Gas-Efficient Patterns

#### Storage Optimization
```solidity
// Bad: Multiple storage writes
contract Inefficient {
    uint256 public value;
    
    function update() public {
        value = 1;  // 20,000 gas
        value = 2;  // 5,000 gas
        value = 3;  // 5,000 gas
    }
}

// Good: Single storage write
contract Efficient {
    uint256 public value;
    
    function update() public {
        uint256 temp = 1;
        temp = 2;
        temp = 3;
        value = temp;  // 20,000 gas only
    }
}
```

#### Batch Operations
```solidity
// Bad: Individual transfers
for (uint i = 0; i < recipients.length; i++) {
    token.transfer(recipients[i], amounts[i]);
}

// Good: Batch transfer
token.batchTransfer(recipients, amounts);
```

### Fee Calculation Examples

#### Simple Transfer
```javascript
// Cosmos SDK
const fee = {
  amount: [{ denom: "uflora", amount: "5000" }],
  gas: "200000"
};

// EVM
const tx = {
  to: recipient,
  value: ethers.parseEther("1.0"),
  gasLimit: 21000,
  gasPrice: ethers.parseUnits("10", "gwei")
};
// Cost: 21,000 * 10 gwei = 210,000 gwei = 0.00021 ETH equivalent
```

#### Smart Contract Deployment
```javascript
const deploymentTx = {
  data: contractBytecode,
  gasLimit: 2000000,
  maxFeePerGas: ethers.parseUnits("50", "gwei"),
  maxPriorityFeePerGas: ethers.parseUnits("2", "gwei")
};
// Maximum cost: 2,000,000 * 50 gwei = 0.1 ETH equivalent
```

### Monitoring and Analytics

#### Track Gas Usage
```javascript
// Monitor transaction gas usage
const receipt = await tx.wait();
console.log(`Gas used: ${receipt.gasUsed}`);
console.log(`Effective gas price: ${receipt.effectiveGasPrice}`);
console.log(`Total fee: ${receipt.gasUsed * receipt.effectiveGasPrice}`);
```

#### Gas Price Oracle
```javascript
// Get current gas prices
async function getGasPrices() {
  const baseFee = await provider.getBlock("latest").baseFeePerGas;
  const gasPrice = await provider.getGasPrice();
  
  return {
    slow: baseFee,
    standard: baseFee * 110n / 100n,  // 10% above base
    fast: baseFee * 150n / 100n       // 50% above base
  };
}
```

## Configuration Reference

### Genesis Configuration
```json
{
  "app_state": {
    "feemarket": {
      "params": {
        "no_base_fee": false,
        "base_fee": "1000000000",
        "min_gas_price": "0.000000001",
        "elasticity_multiplier": 2
      }
    },
    "evm": {
      "params": {
        "evm_denom": "uflora",
        "enable_create": true,
        "enable_call": true,
        "extra_eips": [],
        "chain_config": {
          "chain_id": "766999"
        }
      }
    }
  },
  "consensus_params": {
    "block": {
      "max_gas": "100000000"
    }
  }
}
```

### Runtime Configuration
```toml
# app.toml
minimum-gas-prices = "0.025uflora"

[evm]
max_tx_gas_wanted = 40000000

[feemarket]
no_base_fee = false
base_fee = "1000000000"
```

## Troubleshooting

### Common Issues

1. **"Out of gas" errors**
   - Increase gas limit
   - Check for infinite loops
   - Optimize contract code

2. **"Insufficient fees"**
   - Increase gas price
   - Check account balance
   - Verify fee denomination

3. **"Transaction underpriced"**
   - Current gas price is higher than provided
   - Use dynamic gas pricing
   - Check mempool congestion

4. **"Exceeds block gas limit"**
   - Transaction requires too much gas
   - Split into multiple transactions
   - Optimize contract operations

### Debug Commands
```bash
# Check current gas prices
florad query feemarket params

# Check base fee
florad query feemarket base-fee

# Simulate transaction
florad tx bank send [from] [to] [amount] --dry-run

# Get account balance
florad query bank balances [address]
```

## Further Resources

- [Ethereum Gas Documentation](https://ethereum.org/en/developers/docs/gas/)
- [EIP-1559 Specification](https://eips.ethereum.org/EIPS/eip-1559)
- [Cosmos SDK Gas Documentation](https://docs.cosmos.network/main/basics/gas-fees)
- [Flora Testnet Explorer](https://testnet.flora.network)