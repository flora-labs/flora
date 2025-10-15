# Flora RPC Load Balancer Setup

This Terraform configuration sets up an AWS Application Load Balancer for `rpc.flora.network`.

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** installed (v1.0+)
3. **Domain** `flora.network` with DNS management access
4. **SSL Certificate** in AWS Certificate Manager for `rpc.flora.network`

## Quick Setup

### 1. Request SSL Certificate
```bash
# In AWS Certificate Manager (us-west-1)
# Request certificate for: rpc.flora.network
# Validate via DNS or email
```

### 2. Configure Terraform
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 3. Deploy
```bash
terraform init
terraform plan
terraform apply
```

### 4. Update DNS
After deployment, add CNAME record:
```
rpc.flora.network  CNAME  <alb_dns_name from terraform output>
```

## What This Creates

- ✅ Application Load Balancer with HTTPS
- ✅ Target group with all 3 Flora nodes
- ✅ Health checks every 30 seconds
- ✅ Automatic failover if node fails
- ✅ CloudWatch alarms for monitoring
- ✅ HTTP→HTTPS redirect

## Cost

~$25/month for ALB + ~$0.008/GB data transfer

## Testing

After setup, test with:
```bash
curl https://rpc.flora.network \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
```

## Monitoring

Check ALB health:
- AWS Console → EC2 → Load Balancers → flora-rpc-alb
- Target Health: EC2 → Target Groups → flora-rpc-tg

## Troubleshooting

If targets show unhealthy:
1. Check security groups allow ALB→Nodes on port 8545
2. Verify nodes are running: `curl http://52.9.17.25:8545`
3. Check CloudWatch logs for ALB