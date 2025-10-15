#!/bin/bash

# Setup HTTPS for rpc.flora.network using AWS ALB

set -e

echo "========================================="
echo "Setting up HTTPS for rpc.flora.network"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check AWS CLI
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS CLI not configured${NC}"
    exit 1
fi

echo "AWS Account: $(aws sts get-caller-identity --query 'Account' --output text)"
echo ""

# Step 1: Find existing resources
echo -e "${YELLOW}Step 1: Finding existing AWS resources...${NC}"

# Get VPC ID
VPC_ID=$(aws ec2 describe-vpcs --query "Vpcs[0].VpcId" --output text)
echo "VPC ID: $VPC_ID"

# Find ALB
echo ""
echo "Available Load Balancers:"
aws elbv2 describe-load-balancers --query "LoadBalancers[*].[LoadBalancerName,DNSName]" --output table

echo ""
read -p "Enter the Load Balancer name to use (e.g., main-alb): " ALB_NAME

ALB_ARN=$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null)
if [ -z "$ALB_ARN" ] || [ "$ALB_ARN" == "None" ]; then
    echo -e "${RED}Error: Load balancer '$ALB_NAME' not found${NC}"
    exit 1
fi

ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --query "LoadBalancers[0].DNSName" --output text)
ALB_ZONE_ID=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --query "LoadBalancers[0].CanonicalHostedZoneId" --output text)

echo -e "${GREEN}✓ Found ALB: $ALB_NAME${NC}"
echo "  DNS: $ALB_DNS"
echo ""

# Check for existing certificate
echo -e "${YELLOW}Step 2: Checking SSL certificate...${NC}"
CERT_ARN=$(aws acm list-certificates --query "CertificateSummaryList[?contains(DomainName,'flora.network')].CertificateArn | [0]" --output text)

if [ -z "$CERT_ARN" ] || [ "$CERT_ARN" == "None" ]; then
    echo -e "${RED}No SSL certificate found for flora.network${NC}"
    echo "Please create one in ACM for *.flora.network or rpc.flora.network"
    exit 1
fi

echo -e "${GREEN}✓ Found certificate: $CERT_ARN${NC}"
echo ""

# Step 3: Create Target Group
echo -e "${YELLOW}Step 3: Creating target group for RPC nodes...${NC}"

# Check if target group already exists
TG_EXISTS=$(aws elbv2 describe-target-groups --names "flora-rpc-tg" --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null || echo "")

if [ ! -z "$TG_EXISTS" ] && [ "$TG_EXISTS" != "None" ]; then
    echo "Target group 'flora-rpc-tg' already exists"
    read -p "Use existing target group? (yes/no): " use_existing
    if [ "$use_existing" == "yes" ]; then
        TG_ARN="$TG_EXISTS"
    else
        echo "Please delete the existing target group first"
        exit 1
    fi
else
    TG_ARN=$(aws elbv2 create-target-group \
        --name flora-rpc-tg \
        --protocol HTTP \
        --port 8545 \
        --vpc-id "$VPC_ID" \
        --target-type ip \
        --health-check-protocol HTTP \
        --health-check-port 8545 \
        --health-check-path / \
        --health-check-interval-seconds 30 \
        --matcher HttpCode=200,404,405 \
        --query "TargetGroups[0].TargetGroupArn" \
        --output text)

    echo -e "${GREEN}✓ Created target group${NC}"
fi

echo "Target Group ARN: $TG_ARN"
echo ""

# Step 4: Register targets
echo -e "${YELLOW}Step 4: Registering Flora nodes with target group...${NC}"
aws elbv2 register-targets \
    --target-group-arn "$TG_ARN" \
    --targets Id=52.9.17.25,Port=8545 Id=50.18.34.12,Port=8545 Id=204.236.162.240,Port=8545

echo -e "${GREEN}✓ Registered 3 Flora nodes${NC}"
echo ""

# Step 5: Create HTTPS listener rule
echo -e "${YELLOW}Step 5: Creating HTTPS listener rule...${NC}"

HTTPS_LISTENER_ARN=$(aws elbv2 describe-listeners \
    --load-balancer-arn "$ALB_ARN" \
    --query "Listeners[?Port==\`443\`].ListenerArn" \
    --output text)

if [ -z "$HTTPS_LISTENER_ARN" ]; then
    echo "No HTTPS listener found on ALB. Creating one..."
    HTTPS_LISTENER_ARN=$(aws elbv2 create-listener \
        --load-balancer-arn "$ALB_ARN" \
        --protocol HTTPS \
        --port 443 \
        --certificates CertificateArn="$CERT_ARN" \
        --default-actions Type=fixed-response,FixedResponseConfig={StatusCode=404} \
        --query "Listeners[0].ListenerArn" \
        --output text)
fi

# Check if rule already exists
RULE_EXISTS=$(aws elbv2 describe-rules \
    --listener-arn "$HTTPS_LISTENER_ARN" \
    --query "Rules[?contains(Conditions[0].Values[0],'rpc.flora.network')].RuleArn" \
    --output text 2>/dev/null || echo "")

if [ ! -z "$RULE_EXISTS" ] && [ "$RULE_EXISTS" != "None" ]; then
    echo "HTTPS rule for rpc.flora.network already exists"
else
    aws elbv2 create-rule \
        --listener-arn "$HTTPS_LISTENER_ARN" \
        --priority 101 \
        --conditions Field=host-header,Values=rpc.flora.network \
        --actions Type=forward,TargetGroupArn="$TG_ARN" \
        --output text > /dev/null

    echo -e "${GREEN}✓ Created HTTPS listener rule${NC}"
fi
echo ""

# Step 6: Create HTTP redirect rule
echo -e "${YELLOW}Step 6: Creating HTTP->HTTPS redirect...${NC}"

HTTP_LISTENER_ARN=$(aws elbv2 describe-listeners \
    --load-balancer-arn "$ALB_ARN" \
    --query "Listeners[?Port==\`80\`].ListenerArn" \
    --output text)

if [ ! -z "$HTTP_LISTENER_ARN" ]; then
    # Check if redirect rule exists
    HTTP_RULE_EXISTS=$(aws elbv2 describe-rules \
        --listener-arn "$HTTP_LISTENER_ARN" \
        --query "Rules[?contains(Conditions[0].Values[0],'rpc.flora.network')].RuleArn" \
        --output text 2>/dev/null || echo "")

    if [ -z "$HTTP_RULE_EXISTS" ] || [ "$HTTP_RULE_EXISTS" == "None" ]; then
        aws elbv2 create-rule \
            --listener-arn "$HTTP_LISTENER_ARN" \
            --priority 101 \
            --conditions Field=host-header,Values=rpc.flora.network \
            --actions Type=redirect,RedirectConfig="{Protocol=HTTPS,Port=443,StatusCode=HTTP_301}" \
            --output text > /dev/null

        echo -e "${GREEN}✓ Created HTTP redirect rule${NC}"
    else
        echo "HTTP redirect rule already exists"
    fi
fi
echo ""

# Step 7: Update DNS to point to ALB
echo -e "${YELLOW}Step 7: Updating DNS to point to ALB...${NC}"

HOSTED_ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='flora.network.'].Id" --output text | cut -d'/' -f3)

cat > /tmp/rpc-alb-dns.json <<EOF
{
  "Comment": "Update rpc.flora.network to point to ALB for HTTPS",
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

echo -e "${GREEN}✓ Updated DNS to point to ALB${NC}"
echo ""

# Clean up
rm -f /tmp/rpc-alb-dns.json

# Step 8: Check target health
echo -e "${YELLOW}Step 8: Checking target health...${NC}"
sleep 5

aws elbv2 describe-target-health \
    --target-group-arn "$TG_ARN" \
    --query "TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]" \
    --output table

echo ""
echo "========================================="
echo -e "${GREEN}HTTPS Setup Complete!${NC}"
echo "========================================="
echo ""
echo "RPC endpoint is now available at:"
echo -e "${GREEN}  https://rpc.flora.network${NC}"
echo ""
echo "DNS may take a few minutes to propagate globally."
echo ""
echo "Test commands:"
echo "  # Test HTTPS"
echo "  curl -X POST -H 'Content-Type: application/json' \\"
echo "    --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_chainId\",\"params\":[],\"id\":1}' \\"
echo "    https://rpc.flora.network"
echo ""
echo "  # Test HTTP redirect"
echo "  curl -I http://rpc.flora.network"
echo ""
echo "MetaMask Configuration:"
echo "  Network Name: Flora Network"
echo "  RPC URL: https://rpc.flora.network"
echo "  Chain ID: 9000"
echo "  Symbol: FLORA"
echo ""