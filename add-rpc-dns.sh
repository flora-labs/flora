#!/bin/bash

# Add rpc.flora.network DNS records to Route53

set -e

echo "========================================="
echo "Adding rpc.flora.network to Route53"
echo "========================================="
echo ""

# Check AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "Error: AWS CLI is not configured"
    echo "Run: aws configure"
    exit 1
fi

echo "Current AWS Account:"
aws sts get-caller-identity --query 'Account' --output text
echo ""

# Get the hosted zone ID for flora.network
echo "Finding flora.network hosted zone..."
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='flora.network.'].Id" --output text | cut -d'/' -f3)

if [ -z "$HOSTED_ZONE_ID" ]; then
    echo "Error: No hosted zone found for flora.network"
    echo ""
    echo "Available hosted zones:"
    aws route53 list-hosted-zones --query "HostedZones[*].[Name,Id]" --output table
    exit 1
fi

echo "Found hosted zone: $HOSTED_ZONE_ID"
echo ""

# Check if rpc.flora.network already exists
echo "Checking if rpc.flora.network already exists..."
EXISTING=$(aws route53 list-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --query "ResourceRecordSets[?Name=='rpc.flora.network.'].Name" --output text 2>/dev/null)

if [ ! -z "$EXISTING" ]; then
    echo "Warning: rpc.flora.network already exists"
    read -p "Do you want to update it? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Cancelled"
        exit 0
    fi
    ACTION="UPSERT"
else
    ACTION="CREATE"
fi

# Create the JSON for Route53 change batch
cat > /tmp/rpc-dns-change.json <<EOF
{
  "Comment": "Add rpc.flora.network pointing to Flora RPC nodes",
  "Changes": [
    {
      "Action": "$ACTION",
      "ResourceRecordSet": {
        "Name": "rpc.flora.network",
        "Type": "A",
        "TTL": 60,
        "ResourceRecords": [
          { "Value": "52.9.17.25" },
          { "Value": "50.18.34.12" },
          { "Value": "204.236.162.240" }
        ]
      }
    }
  ]
}
EOF

echo "Adding DNS records..."
echo "  rpc.flora.network -> 52.9.17.25"
echo "  rpc.flora.network -> 50.18.34.12"
echo "  rpc.flora.network -> 204.236.162.240"
echo ""

# Apply the change
CHANGE_ID=$(aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch file:///tmp/rpc-dns-change.json \
  --query 'ChangeInfo.Id' \
  --output text)

echo "DNS change submitted: $CHANGE_ID"
echo ""

# Wait for change to propagate
echo "Waiting for DNS propagation..."
aws route53 wait resource-record-sets-changed --id $CHANGE_ID 2>/dev/null || true

echo ""
echo "✅ DNS records created successfully!"
echo ""

# Clean up
rm -f /tmp/rpc-dns-change.json

# Test DNS resolution
echo "Testing DNS resolution (may take a few minutes to propagate globally)..."
echo ""

# Try multiple DNS servers
for dns in 8.8.8.8 1.1.1.1; do
    echo "Testing with DNS server $dns:"
    nslookup rpc.flora.network $dns 2>&1 | grep -A 2 "Address" | tail -2 || echo "Not propagated yet"
    echo ""
done

echo "========================================="
echo "DNS Setup Complete!"
echo "========================================="
echo ""
echo "The following DNS records have been added:"
echo "  rpc.flora.network A 52.9.17.25 (TTL: 60s)"
echo "  rpc.flora.network A 50.18.34.12 (TTL: 60s)"
echo "  rpc.flora.network A 204.236.162.240 (TTL: 60s)"
echo ""
echo "Test the RPC endpoint:"
echo "  curl -X POST -H 'Content-Type: application/json' \\"
echo "    --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_chainId\",\"params\":[],\"id\":1}' \\"
echo "    http://rpc.flora.network:8545"
echo ""
echo "MetaMask Configuration:"
echo "  Network Name: Flora Network"
echo "  RPC URL: http://rpc.flora.network:8545"
echo "  Chain ID: 9000"
echo "  Symbol: FLORA"
echo ""
echo "Note: This is HTTP-only. For HTTPS, you'll need to set up the ALB."
echo ""