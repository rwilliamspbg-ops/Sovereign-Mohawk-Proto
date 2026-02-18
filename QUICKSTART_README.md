Sovereign FL 200-Node Test
Real-world federated learning test infrastructure using AWS.
Quick Start
bash
Copy
# Deploy infrastructure
./scripts/deploy-200-node-test.sh

# Get aggregator IP
cd terraform
AGGREGATOR_IP=$(terraform output -raw aggregator_public_ip)

# SSH to aggregator
ssh -i ~/.ssh/sovereign-fl-key.pem ubuntu@$AGGREGATOR_IP

# Start training
cd /opt/sovereign-fl
python3 aggregator.py

# Monitor
open http://$AGGREGATOR_IP:9090  # Prometheus
open http://$AGGREGATOR_IP:3000  # Grafana

# Cleanup when done
./scripts/destroy-200-node-test.sh
Architecture
1 Aggregator (c5.2xlarge) - Flower server with Multi-Krum
200 Client Nodes (t3.medium spot) - Flower clients with DP-SGD
VPC with 3 AZs
Prometheus + Grafana monitoring
Cost
~$20 per 3-hour test run
Files
terraform/main.tf - AWS infrastructure
src/aggregator.py - FL server with Byzantine tolerance
src/client.py - FL client with differential privacy
scripts/ - Deployment automation
