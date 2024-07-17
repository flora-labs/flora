# Flora
- Flora is based on cosmos-sdk v0.50.6 

If you would like to participate please join our Discord: https://discord.gg/4Qx9UxKMBE

## Modules
- proof-of-stake
- tokenfactory
- globalfee
- ibc-packetforward
- ibc-ratelimit
- cosmwasm
- wasm-light-client
- optimistic-execution

## Content Generation

- `make proto-gen` *Generates golang code from proto files, stubs interfaces*

## Testnet

- `make testnet` *IBC testnet from chain <-> local cosmos-hub*
- `make sh-testnet` *Single node, no IBC. quick iteration*

## Local Images

- `make install`      *Builds the chain's binary*
- `make local-image`  *Builds the chain's docker image*

## Testing

- `go test ./... -v` *Unit test*
- `make ictest-*`  *E2E testing*