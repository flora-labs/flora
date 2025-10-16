# Setting Up rpc.flora.network

Adding `rpc.flora.network` as a unified RPC endpoint would significantly improve wallet connectivity and user experience.

## Benefits of rpc.flora.network

✅ **Single endpoint for all wallets** - No need to choose between nodes
✅ **Professional appearance** - `rpc.flora.network` vs raw IPs
✅ **Load balancing** - Distribute traffic across all nodes
✅ **High availability** - Automatic failover if a node goes down
✅ **Future-proof** - Easy to add/remove nodes without updating clients

## Quick Setup Options

### Option 1: Simple DNS Round-Robin (Immediate, Free)
Add these A records to your DNS:
```
rpc.flora.network  A  52.9.17.25     TTL: 60
rpc.flora.network  A  50.18.34.12    TTL: 60
rpc.flora.network  A  204.236.162.240 TTL: 60
```

**Pros:** Quick, free, works immediately
**Cons:** No health checks, no HTTPS, basic load distribution

### Option 2: AWS Application Load Balancer (Recommended)

#### 1. Create Target Group
```bash
aws elbv2 create-target-group \
  --name flora-rpc-tg \
  --protocol HTTP \
  --port 8545 \
  --vpc-id vpc-xxxxx \
  --target-type ip \
  --health-check-path / \
  --health-check-protocol HTTP \
  --health-check-port 8545 \
  --health-check-interval-seconds 30
```

#### 2. Register Targets
```bash
aws elbv2 register-targets \
  --target-group-arn arn:aws:elasticloadbalancing:... \
  --targets Id=52.9.17.25,Port=8545 \
           Id=50.18.34.12,Port=8545 \
           Id=204.236.162.240,Port=8545
```

#### 3. Create ALB
```bash
aws elbv2 create-load-balancer \
  --name flora-rpc-alb \
  --subnets subnet-xxx subnet-yyy \
  --security-groups sg-xxxxx \
  --scheme internet-facing \
  --type application
```

#### 4. Add HTTPS Listener (with ACM Certificate)
```bash
aws elbv2 create-listener \
  --load-balancer-arn arn:aws:elasticloadbalancing:... \
  --protocol HTTPS \
  --port 443 \
  --certificates CertificateArn=arn:aws:acm:... \
  --default-actions Type=forward,TargetGroupArn=...
```

#### 5. Point DNS to ALB
```
rpc.flora.network  CNAME  flora-rpc-alb-xxxxx.us-west-1.elb.amazonaws.com
```

### Option 3: CloudFlare Load Balancer

1. Add Flora nodes as Origins in CloudFlare
2. Create Load Balancer pool:
   - Name: flora-rpc-pool
   - Origins: All 3 node IPs on port 8545
   - Health Check: HTTP GET to :8545

3. Create Load Balancer:
   - Hostname: rpc.flora.network
   - Pool: flora-rpc-pool
   - Enable SSL/TLS

## Updated Wallet Configuration

Once rpc.flora.network is live:

### MetaMask Configuration - Devnet
```javascript
const FLORA_DEVNET_CONFIG = {
  chainId: '0xBB417',  // 766999 in decimal
  chainName: 'Flora Devnet',
  nativeCurrency: {
    name: 'FLORA',
    symbol: 'FLORA',
    decimals: 18
  },
  rpcUrls: ['https://rpc.devnet.flora.network'],  // Devnet load-balanced endpoint
  blockExplorerUrls: ['https://explorer.devnet.flora.network']
};
```

### MetaMask Configuration - Mainnet (Reserved)
```javascript
const FLORA_MAINNET_CONFIG = {
  chainId: '0xBB349',  // 766793 in decimal (reserved for production)
  chainName: 'Flora Network',
  nativeCurrency: {
    name: 'FLORA',
    symbol: 'FLORA',
    decimals: 18
  },
  rpcUrls: ['https://rpc.flora.network'],  // Mainnet load-balanced endpoint
  blockExplorerUrls: ['https://explorer.flora.network']
};
```

**Note**: Dual chain ID strategy - Devnet uses 766999 (0xBB417), Mainnet reserved for 766793 (0xBB349). See `docs/CHAIN_ID_STRATEGY.md`.

### For Development (Current)
```javascript
// Use domain names instead of IPs
const RPC_ENDPOINTS = [
  'http://seed1.testnet.flora.network:8545',
  'http://seed2.testnet.flora.network:8545',
  'http://seed3.testnet.flora.network:8545'
];
```

### For Production (After Setup)
```javascript
// Single, load-balanced endpoint
const RPC_ENDPOINT = 'https://rpc.flora.network';
```

## Health Check Configuration

For load balancer health checks, create a simple health endpoint:

### JSON-RPC Health Check
Test with:
```bash
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  https://rpc.flora.network
```

Expected response:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0xe85db"  // Current block height in hex
}
```

## Testing After Setup

```bash
#!/bin/bash
echo "Testing rpc.flora.network..."

# Test DNS resolution
echo "1. DNS Resolution:"
nslookup rpc.flora.network

# Test HTTP/HTTPS connectivity
echo -e "\n2. RPC Connectivity:"
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  https://rpc.flora.network | jq .

# Test load balancing (run multiple times)
echo -e "\n3. Load Distribution (run 10 times):"
for i in {1..10}; do
  curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' \
    https://rpc.flora.network \
    --resolve rpc.flora.network:443:$(dig +short rpc.flora.network | head -1) \
    -w " (via %{remote_ip})\n"
done
```

## Monitoring Setup

### CloudWatch Alarms (if using AWS ALB)
```bash
# Unhealthy targets alarm
aws cloudwatch put-metric-alarm \
  --alarm-name flora-rpc-unhealthy-targets \
  --alarm-description "Alert when Flora RPC targets are unhealthy" \
  --metric-name UnHealthyHostCount \
  --namespace AWS/ApplicationELB \
  --statistic Average \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold
```

### Basic Uptime Monitor
```bash
# Add to crontab
*/5 * * * * curl -f https://rpc.flora.network > /dev/null 2>&1 || echo "RPC down" | mail -s "Flora RPC Alert" admin@flora.network
```

## Cost Estimates

| Solution | Monthly Cost | Setup Time |
|----------|-------------|------------|
| DNS Round-Robin | $0 | 5 minutes |
| AWS ALB | ~$25/month | 1 hour |
| CloudFlare LB | $5-50/month | 30 minutes |

## Next Steps

1. **Immediate**: Set up DNS round-robin for `rpc.flora.network`
2. **This Week**: Configure AWS ALB with HTTPS
3. **Future**: Add `api.flora.network` for REST API
4. **Future**: Add `ws.flora.network` for WebSocket

## Contact for DNS Changes

To add `rpc.flora.network`, you need access to:
- Domain registrar (for NS records)
- DNS provider (Route53, CloudFlare, etc.)
- AWS account (if using ALB)
