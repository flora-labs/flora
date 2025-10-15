#!/bin/bash

# Add rpc.flora.network to existing flora-nodes-alb

set -e

echo "========================================="
echo "Adding rpc.flora.network to flora-nodes-alb"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check AWS CLI
if ! aws sts get-caller-identity &> /dev/null; then
    echo "Error: AWS CLI not configured"
    exit 1
fi

echo "AWS Account: $(aws sts get-caller-identity --query 'Account' --output text)"
echo ""

# Get flora-nodes-alb details
echo -e "${YELLOW}Step 1: Getting flora-nodes-alb details...${NC}"
ALB_ARN=$(aws elbv2 describe-load-balancers --names flora-nodes-alb --query "LoadBalancers[0].LoadBalancerArn" --output text)
ALB_DNS=$(aws elbv2 describe-load-balancers --names flora-nodes-alb --query "LoadBalancers[0].DNSName" --output text)
ALB_ZONE_ID=$(aws elbv2 describe-load-balancers --names flora-nodes-alb --query "LoadBalancers[0].CanonicalHostedZoneId" --output text)

echo "ALB ARN: $ALB_ARN"
echo "ALB DNS: $ALB_DNS"
echo ""

# Get existing flora-evm-nodes target group
echo -e "${YELLOW}Step 2: Getting existing EVM target group...${NC}"
TG_ARN=$(aws elbv2 describe-target-groups --names flora-evm-nodes --query "TargetGroups[0].TargetGroupArn" --output text)
echo "Target Group: flora-evm-nodes"
echo "Target Group ARN: $TG_ARN"
echo ""

# Get HTTPS listener
echo -e "${YELLOW}Step 3: Getting HTTPS listener...${NC}"
HTTPS_LISTENER_ARN=$(aws elbv2 describe-listeners \
    --load-balancer-arn "$ALB_ARN" \
    --query "Listeners[?Port==\`443\`].ListenerArn" \
    --output text)
echo "HTTPS Listener ARN: $HTTPS_LISTENER_ARN"
echo ""

# Check if rule already exists
echo -e "${YELLOW}Step 4: Checking if rule already exists...${NC}"
RULE_EXISTS=$(aws elbv2 describe-rules \
    --listener-arn "$HTTPS_LISTENER_ARN" \
    --query "Rules[?contains(Conditions[0].Values[0],'rpc.flora.network')].RuleArn" \
    --output text 2>/dev/null || echo "")

if [ ! -z "$RULE_EXISTS" ] && [ "$RULE_EXISTS" != "None" ]; then
    echo "HTTPS rule for rpc.flora.network already exists"
    echo "Rule ARN: $RULE_EXISTS"
else
    # Create HTTPS listener rule for rpc.flora.network
    echo -e "${YELLOW}Creating HTTPS listener rule for rpc.flora.network...${NC}"

    # Find an available priority
    PRIORITY=103
    while aws elbv2 describe-rules --listener-arn "$HTTPS_LISTENER_ARN" --query "Rules[?Priority==\`$PRIORITY\`].Priority" --output text 2>/dev/null | grep -q "$PRIORITY"; do
        PRIORITY=$((PRIORITY + 1))
    done

    aws elbv2 create-rule \
        --listener-arn "$HTTPS_LISTENER_ARN" \
        --priority $PRIORITY \
        --conditions Field=host-header,Values=rpc.flora.network \
        --actions Type=forward,TargetGroupArn="$TG_ARN" \
        --output text > /dev/null

    echo -e "${GREEN}✓ Created HTTPS listener rule with priority $PRIORITY${NC}"
fi
echo ""

# Create HTTP redirect rule
echo -e "${YELLOW}Step 5: Creating HTTP redirect rule...${NC}"
HTTP_LISTENER_ARN=$(aws elbv2 describe-listeners \
    --load-balancer-arn "$ALB_ARN" \
    --query "Listeners[?Port==\`80\`].ListenerArn" \
    --output text)

if [ ! -z "$HTTP_LISTENER_ARN" ]; then
    HTTP_RULE_EXISTS=$(aws elbv2 describe-rules \
        --listener-arn "$HTTP_LISTENER_ARN" \
        --query "Rules[?contains(Conditions[0].Values[0],'rpc.flora.network')].RuleArn" \
        --output text 2>/dev/null || echo "")

    if [ -z "$HTTP_RULE_EXISTS" ] || [ "$HTTP_RULE_EXISTS" == "None" ]; then
        # Find an available priority
        PRIORITY=103
        while aws elbv2 describe-rules --listener-arn "$HTTP_LISTENER_ARN" --query "Rules[?Priority==\`$PRIORITY\`].Priority" --output text 2>/dev/null | grep -q "$PRIORITY"; do
            PRIORITY=$((PRIORITY + 1))
        done

        aws elbv2 create-rule \
            --listener-arn "$HTTP_LISTENER_ARN" \
            --priority $PRIORITY \
            --conditions Field=host-header,Values=rpc.flora.network \
            --actions Type=redirect,RedirectConfig="{Protocol=HTTPS,Port=443,StatusCode=HTTP_301}" \
            --output text > /dev/null

        echo -e "${GREEN}✓ Created HTTP redirect rule with priority $PRIORITY${NC}"
    else
        echo "HTTP redirect rule already exists"
    fi
fi
echo ""

# Update DNS to point to ALB
echo -e "${YELLOW}Step 6: Updating DNS to point to flora-nodes-alb...${NC}"
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='flora.network.'].Id" --output text | cut -d'/' -f3)

cat > /tmp/rpc-alb-dns.json <<EOF
{
  "Comment": "Update rpc.flora.network to point to flora-nodes-alb for HTTPS",
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "rpc.flora.network",
      "Type": "A",
      "AliasTarget": {
        "HostedZoneId": "$ALB_ZONE_ID",
        "DNSName": "dualstack.$ALB_DNS",
        "EvaluateTargetHealth": true
      }
    }
  }]
}
EOF

CHANGE_ID=$(aws route53 change-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --change-batch file:///tmp/rpc-alb-dns.json \
    --query 'ChangeInfo.Id' \
    --output text)

echo -e "${GREEN}✓ Updated DNS to point to flora-nodes-alb${NC}"
echo "Change ID: $CHANGE_ID"
rm -f /tmp/rpc-alb-dns.json
echo ""

# Wait for DNS propagation
echo -e "${YELLOW}Step 7: Waiting for DNS propagation...${NC}"
aws route53 wait resource-record-sets-changed --id $CHANGE_ID 2>/dev/null || true
echo -e "${GREEN}✓ DNS change completed${NC}"
echo ""

# Test the endpoint
echo -e "${YELLOW}Step 8: Testing the endpoint...${NC}"
sleep 5

echo "Testing HTTPS..."
if curl -s --max-time 10 -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
    https://rpc.flora.network 2>/dev/null | jq -r '.result' | grep -q "0x"; then
    echo -e "${GREEN}✓ HTTPS endpoint is working!${NC}"

    echo ""
    echo "Response:"
    curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
        https://rpc.flora.network | jq .
else
    echo "⚠️  HTTPS not responding yet. DNS may still be propagating."
    echo "Try again in a minute with:"
    echo "  curl https://rpc.flora.network"
fi

echo ""
echo "========================================="
echo -e "${GREEN}Setup Complete!${NC}"
echo "========================================="
echo ""
echo "RPC endpoint is now available at:"
echo -e "${GREEN}  https://rpc.flora.network${NC}"
echo ""
echo "Also available:"
echo "  https://testnet-evm.flora.network (same endpoint)"
echo "  https://testnet-rpc.flora.network (Tendermint RPC)"
echo "  https://testnet-api.flora.network (Cosmos API)"
echo ""
echo "MetaMask Configuration:"
echo "  Network Name: Flora Network"
echo "  RPC URL: https://rpc.flora.network"
echo "  Chain ID: 9000"
echo "  Symbol: FLORA"
echo ""