# Flora DevNet Node SSH Access

## Connection Details

**SSH Key:** `~/.ssh/esprezzo/norcal-pub.pem`
**Username:** `ubuntu`

## Node IPs
- 52.9.17.25
- 50.18.34.12
- 204.236.162.240

## Example Commands

```bash
# SSH into node
ssh -i ~/.ssh/esprezzo/norcal-pub.pem ubuntu@52.9.17.25

# Get genesis file
scp -i ~/.ssh/esprezzo/norcal-pub.pem ubuntu@52.9.17.25:~/.flora/config/genesis.json ./genesis.json

# Check node status
ssh -i ~/.ssh/esprezzo/norcal-pub.pem ubuntu@52.9.17.25 "florad status"
```

## Genesis Information
- **Chain ID:** flora_766999-1
- **Genesis Time:** 2025-10-16T11:01:38.492971955Z
- **Location on nodes:** ~/.flora/config/genesis.json