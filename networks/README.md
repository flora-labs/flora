# Flora Network Genesis Files

## DevNet Genesis

To join the Flora DevNet, you need the correct genesis file.

### Getting the Genesis File

**Current Issue:** The genesis file needs to be obtained from a running node operator.

**Options to get genesis:**

1. **From a running node (if you have access):**
   ```bash
   scp user@NODE_IP:~/.flora/config/genesis.json ./genesis.json
   ```

2. **From RPC endpoint (if exposed):**
   ```bash
   curl http://NODE_IP:26657/genesis | jq .result.genesis > genesis.json
   ```

3. **Request from team:**
   - Contact the Flora team on Discord
   - Request the current DevNet genesis file

### Current DevNet Seeds

```
e3e06f1efeeca5daf7c7c0ad6a2216c0cadfa676@52.9.17.25:26656
ebf668f4d1e2b21e895e7889050ebb43364c18b3@50.18.34.12:26656
22a444539995192ada565f118069f11c0069e67e@204.236.162.240:26656
```

### Important Note

The genesis file must match exactly with what the running network is using. Using an incorrect genesis file will prevent your node from syncing with the network.

## Network Information

- **Chain ID:** flora_766999-1
- **Native Token:** uflora
- **EVM Chain ID:** 766999 (0xBB417)