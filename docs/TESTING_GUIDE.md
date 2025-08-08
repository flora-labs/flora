# Flora Testing Guide

This comprehensive guide covers all aspects of testing the Flora EVM-compatible Cosmos blockchain.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Test Levels](#test-levels)
- [Writing Tests](#writing-tests)
- [Testing Tools](#testing-tools)
- [CI/CD Integration](#cicd-integration)
- [Performance Testing](#performance-testing)
- [Troubleshooting](#troubleshooting)

## Prerequisites

- **Go** 1.21+ (required)
- **Make** (required)
- **Docker & Docker Compose** (required for interchaintest)
- **Node.js & npm/yarn** (optional, for EVM contract testing)
- **Foundry** (optional, for EVM contract testing)
- **jq** (optional, for JSON processing)

## Quick Start

### Running All Basic Tests
```bash
# Run all unit tests
make test

# Run tests with race detection
make test-race

# Generate code coverage report
make test-cover

# Run system tests
make test-system

# Launch local testnet for manual testing
make testnet
```

### Running Integration Tests
```bash
# Basic chain e2e test
make ictest-basic

# IBC functionality test
make ictest-ibc

# Token Factory test
make ictest-tokenfactory

# Rate limiting test
make ictest-ratelimit
```

## Test Levels

### 1. Unit Tests
Fast, isolated tests for individual components.

**Location:** `*_test.go` files throughout the codebase  
**Run:** `make test-unit` or `go test ./...`  
**Single package:** `go test ./x/yourmodule/...`  
**Single test:** `go test ./x/yourmodule/... -run TestName -v`  
**With race detection:** `make test-race`

### 2. System Tests
Tests that validate module interactions within a single chain.

**Location:** `tests/system/`  
**Run:** `make test-system`

### 3. Integration Tests (E2E)
Dockerized multi-chain tests with relayers and realistic network conditions.

**Location:** `interchaintest/`  
**Run:** `make ictest-basic` (or other `ictest-*` targets)  
**Specific test:** `cd interchaintest && go test -v -run TestName -timeout 30m`

### 4. Simulation Tests
Random operation simulations to test state machine safety and determinism.

**Commands:**
```bash
# Import/Export test
make test-sim-import-export

# Multi-seed test
make test-sim-multi-seed-short

# Determinism check
make test-sim-deterministic
```

## Writing Tests

### Cosmos SDK Module Tests

#### Keeper Unit Test Example
```go
package keeper_test

import (
    "testing"
    
    "github.com/stretchr/testify/require"
    "github.com/stretchr/testify/suite"
    
    sdk "github.com/cosmos/cosmos-sdk/types"
    "github.com/flora-labs/flora/app"
)

type KeeperTestSuite struct {
    suite.Suite
    App *app.App
    Ctx sdk.Context
}

func (s *KeeperTestSuite) SetupTest() {
    s.App = app.Setup(s.T(), false)
    s.Ctx = s.App.BaseApp.NewContext(false, tmproto.Header{})
}

func (s *KeeperTestSuite) TestYourFunction() {
    k := s.App.YourModuleKeeper
    
    // Test logic here
    result := k.GetSomething(s.Ctx)
    s.Require().NotNil(result)
}

func TestKeeperTestSuite(t *testing.T) {
    suite.Run(t, new(KeeperTestSuite))
}
```

#### Message Server Test Example
```go
func (s *KeeperTestSuite) TestMsgExecute() {
    msgSrv := keeper.NewMsgServerImpl(s.App.YourModuleKeeper)
    goCtx := sdk.WrapSDKContext(s.Ctx)
    
    msg := &types.MsgExecute{
        Creator: s.Addr.String(),
        Value:   100,
    }
    
    _, err := msgSrv.Execute(goCtx, msg)
    s.Require().NoError(err)
    
    // Verify state changes
    state := s.App.YourModuleKeeper.GetState(s.Ctx, s.Addr)
    s.Require().Equal(int64(100), state.Value)
}
```

### EVM Smart Contract Tests

#### Option A: Using Foundry
```bash
# Start local testnet
make testnet

# Check EVM RPC is available
cast rpc --rpc-url http://localhost:8545 eth_chainId

# Deploy contract
forge create src/YourContract.sol:YourContract \
    --rpc-url http://localhost:8545 \
    --private-key $PRIVATE_KEY

# Interact with contract
cast send $CONTRACT_ADDRESS "setValue(uint256)" 123 \
    --rpc-url http://localhost:8545 \
    --private-key $PRIVATE_KEY

# Read from contract
cast call $CONTRACT_ADDRESS "getValue()(uint256)" \
    --rpc-url http://localhost:8545
```

#### Option B: Using Hardhat
```javascript
// hardhat.config.js
module.exports = {
    networks: {
        flora: {
            url: "http://localhost:8545",
            chainId: 7668378,
            accounts: [process.env.PRIVATE_KEY]
        }
    }
};

// test/YourContract.test.js
describe("YourContract", function() {
    it("Should set and get value", async function() {
        const Contract = await ethers.getContractFactory("YourContract");
        const contract = await Contract.deploy();
        
        await contract.setValue(123);
        expect(await contract.getValue()).to.equal(123);
    });
});
```

#### Option C: Go-based Contract Tests
```go
package contract_tests

import (
    "testing"
    "github.com/ethereum/go-ethereum/ethclient"
    "github.com/stretchr/testify/require"
)

func TestContractInteraction(t *testing.T) {
    // Connect to local node
    client, err := ethclient.Dial("http://localhost:8545")
    require.NoError(t, err)
    defer client.Close()
    
    // Deploy and test contract
    // ... deployment and interaction code
}
```

### IBC Tests

#### Unit Test for IBC Module
```go
func TestIBCPacketHandling(t *testing.T) {
    app := app.Setup(t, false)
    ctx := app.BaseApp.NewContext(false, tmproto.Header{})
    
    // Mock IBC packet
    packet := channeltypes.NewPacket(
        []byte("test data"),
        1,
        "transfer",
        "channel-0",
        "transfer",
        "channel-1",
        clienttypes.Height{},
        0,
    )
    
    // Test packet handling
    err := app.TransferKeeper.OnRecvPacket(ctx, packet)
    require.NoError(t, err)
}
```

#### Full IBC E2E Test
```go
func TestIBCTransfer(t *testing.T) {
    ctx := context.Background()
    
    // Setup two chains
    cf := interchaintest.NewBuiltinChainFactory(nil, []interchaintest.ChainSpec{
        {
            Name:    "flora",
            Version: "local",
            ChainConfig: ibc.ChainConfig{
                ChainID: "flora-1",
            },
        },
        {
            Name:    "flora",
            Version: "local", 
            ChainConfig: ibc.ChainConfig{
                ChainID: "flora-2",
            },
        },
    })
    
    chains, err := cf.Chains(t.Name())
    require.NoError(t, err)
    
    // Setup interchain with relayer
    ic := interchaintest.NewInterchain().
        AddChain(chains[0]).
        AddChain(chains[1]).
        AddRelayer(rly, "relayer").
        AddLink(interchaintest.InterchainLink{
            Chain1:  chains[0],
            Chain2:  chains[1],
            Relayer: rly,
        })
    
    // Build and start
    require.NoError(t, ic.Build(ctx, client, network))
    t.Cleanup(func() { _ = ic.Close() })
    
    // Test IBC transfer
    // ... transfer logic and assertions
}
```

## Testing Tools

### Core Tools
- **testify** - Assertions and test suites
- **go-cmp** - Structured comparison
- **golangci-lint** - Linting and static analysis

### Cosmos SDK Utilities
- **simtestutil** - Simulation helpers
- **testutil/network** - In-process network setup

### EVM Testing
- **Foundry** - `forge test`, `cast` commands
- **Hardhat** - JavaScript/TypeScript testing
- **go-ethereum** - Go client for EVM interaction

### Integration Testing
- **interchaintest** - Multi-chain Docker-based testing
- **Docker Compose** - Container orchestration

## CI/CD Integration

### GitHub Actions Workflow Example

```yaml
name: Tests
on: [pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.21'
      - name: Cache Go modules
        uses: actions/cache@v4
        with:
          path: |
            ~/.cache/go-build
            ~/go/pkg/mod
          key: ${{ runner.os }}-go-${{ hashFiles('**/go.sum') }}
      - name: Run unit tests
        run: make test-unit
      - name: Run race tests
        run: make test-race
      - name: Generate coverage
        run: make test-cover
      - name: Upload coverage
        uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage.out

  integration-tests:
    runs-on: ubuntu-latest
    services:
      docker:
        image: docker:24-dind
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.21'
      - name: Run basic e2e
        run: make ictest-basic
        timeout-minutes: 30
      - name: Upload logs on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: test-logs
          path: "**/*.log"

  simulation-tests:
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/master'
    timeout-minutes: 120
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.21'
      - name: Run simulations
        run: |
          make test-sim-deterministic
          make test-sim-import-export
```

## Performance Testing

### Load Testing EVM RPC
```bash
# Start testnet
make testnet

# Simple load test with parallel transactions
export RPC=http://localhost:8545
export CONTRACT=0x... # Your contract address
export PK=0x...       # Test private key

# Send 1000 transactions in parallel
for i in $(seq 1 1000); do
    cast send $CONTRACT "ping()" \
        --rpc-url $RPC \
        --private-key $PK \
        --gas-price 1000000000 \
        --legacy >/dev/null &
done
wait
```

### Load Testing Cosmos SDK
```bash
# Using vegeta for REST API load testing
echo "GET http://localhost:1317/cosmos/bank/v1beta1/supply" | \
    vegeta attack -duration=60s -rate=50 | \
    vegeta report
```

### Benchmarking
```bash
# Run Go benchmarks
go test -bench=. ./...

# Run specific benchmark
go test -bench=BenchmarkTransfer ./x/bank/...

# With memory profiling
go test -bench=. -benchmem ./...
```

## Local Testnet Usage

### Starting the Testnet
```bash
# Start with default configuration
make testnet

# Start with custom shell environment
make sh-testnet
```

### Default Endpoints
- **Tendermint RPC:** http://localhost:26657
- **EVM JSON-RPC:** http://localhost:8545
- **gRPC:** localhost:9090
- **REST/LCD:** http://localhost:1317

### Quick Health Checks
```bash
# Check consensus layer
curl http://localhost:26657/status | jq .

# Check EVM layer
curl -X POST http://localhost:8545 \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}'

# Check block production
watch -n 1 'curl -s http://localhost:26657/status | jq .result.sync_info.latest_block_height'
```

## Troubleshooting

### Common Issues

#### Port Conflicts
```bash
# Check if ports are in use
lsof -i :26657
lsof -i :8545

# Kill existing processes or change ports in config
```

#### Docker Issues for Interchaintest
```bash
# Ensure Docker is running
docker ps

# Clean up old containers
docker system prune -a

# Increase Docker resources if tests timeout
```

#### Test Timeouts
```bash
# Increase timeout for specific test
go test -timeout 60m ./interchaintest/...

# For make targets, check Makefile for timeout settings
```

#### Race Condition Failures
- Review shared state access
- Use proper synchronization primitives
- Avoid global variables
- Be careful with `t.Parallel()`

#### Simulation Non-determinism
- Always use fixed seeds
- Log seed values on failure
- Avoid time.Now() in tested code
- Check for map iteration order dependencies

## Command Reference

| Command | Description |
|---------|-------------|
| `make test` | Run unit tests |
| `make test-unit` | Basic unit tests |
| `make test-race` | Tests with race detection |
| `make test-cover` | Generate coverage report |
| `make test-system` | System-level tests |
| `make test-sim-import-export` | Simulation: import/export |
| `make test-sim-multi-seed-short` | Simulation: multi-seed |
| `make test-sim-deterministic` | Simulation: determinism |
| `make ictest-basic` | Basic interchain e2e |
| `make ictest-ibc` | IBC e2e test |
| `make ictest-tokenfactory` | Token Factory e2e |
| `make ictest-ratelimit` | Rate limiting e2e |
| `make testnet` | Start local testnet |
| `make sh-testnet` | Shell with testnet env |

## Best Practices

1. **Keep tests fast** - Unit tests should run in <1s
2. **Use deterministic data** - Fixed seeds, no wall clock time
3. **Isolate test state** - Fresh stores per test
4. **Test error paths** - Not just happy paths
5. **Validate events** - Check emitted events, not just state
6. **Use require for failures** - `require.NoError()` for critical assertions
7. **Clean up resources** - Use `t.Cleanup()` for deferred cleanup
8. **Document complex tests** - Add comments explaining test scenarios
9. **Run locally first** - Test locally before pushing
10. **Monitor CI failures** - Fix flaky tests immediately

## Contributing Tests

When adding new features:
1. Write unit tests in the same package
2. Add integration tests if crossing module boundaries
3. Update this guide if adding new test patterns
4. Ensure all tests pass: `make test-all`
5. Check coverage: `make test-cover`

## Need Help?

- Check existing tests in `interchaintest/` for patterns
- Review `tests/system/` for system test examples
- Look at `cmd/contract_tests/` for EVM patterns
- Open an issue with logs and exact commands if tests fail