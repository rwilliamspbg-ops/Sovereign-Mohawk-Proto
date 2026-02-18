#!/bin/bash
#================================================================================
# PHASE 3: CODE DEPLOYMENT
# Upload FL code to S3 and deploy to all nodes
#================================================================================

set -e

echo "=========================================="
echo "PHASE 3: Code Deployment"
echo "=========================================="

# Load configuration
if [[ -f aws-config.env ]]; then
    source aws-config.env
else
    echo "Error: aws-config.env not found. Run Phase 1 first."
    exit 1
fi

if [[ -f deployment-outputs.env ]]; then
    source deployment-outputs.env
else
    echo "Error: deployment-outputs.env not found. Run Phase 2 first."
    exit 1
fi

#================================================================================
# PHASE 3.1: PREPARE CODE BUNDLE
#================================================================================

echo ""
echo "Step 3.1: Preparing code bundle..."

# Create code directory
mkdir -p code-bundle
cd code-bundle

# Create aggregator.py
cat > aggregator.py << 'EOF'
#!/usr/bin/env python3
"""Sovereign FL Aggregator with Multi-Krum Byzantine tolerance"""

import flwr as fl
from typing import List, Dict, Optional
import torch
import torch.nn as nn
import torch.nn.functional as F
import numpy as np
from dataclasses import dataclass
from prometheus_client import start_http_server, Counter, Histogram, Gauge, Info
import json
import time
import logging
from datetime import datetime
import boto3

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/sovereign-aggregator.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

ROUND_COUNTER = Counter('fl_rounds_total', 'Total FL rounds completed')
ACCURACY_GAUGE = Gauge('fl_accuracy', 'Current model accuracy')
LOSS_HISTOGRAM = Histogram('fl_loss', 'Training loss distribution')
CLIENT_GAUGE = Gauge('fl_connected_clients', 'Number of connected clients')
BYZANTINE_COUNTER = Counter('fl_byzantine_detected', 'Byzantine nodes detected')
GRADIENT_NORM = Histogram('fl_gradient_norm', 'Gradient norm distribution')
ROUND_DURATION = Histogram('fl_round_duration_seconds', 'Time per round')

@dataclass
class MultiKrumConfig:
    num_clients: int = 200
    num_byzantine: int = 20
    num_selection: int = 180

class MNISTNet(nn.Module):
    def __init__(self):
        super(MNISTNet, self).__init__()
        self.conv1 = nn.Conv2d(1, 32, 3, 1)
        self.conv2 = nn.Conv2d(32, 64, 3, 1)
        self.fc1 = nn.Linear(9216, 128)
        self.fc2 = nn.Linear(128, 10)

    def forward(self, x):
        x = F.relu(self.conv1(x))
        x = F.relu(self.conv2(x))
        x = F.max_pool2d(x, 2)
        x = torch.flatten(x, 1)
        x = F.relu(self.fc1(x))
        x = self.fc2(x)
        return F.log_softmax(x, dim=1)

class MultiKrumStrategy(fl.server.strategy.Strategy):
    def __init__(self, config: MultiKrumConfig, model: nn.Module):
        self.config = config
        self.model = model
        self.round_num = 0
        self.byzantine_detected = 0

    def initialize_parameters(self, client_manager):
        return [val.cpu().numpy() for _, val in self.model.state_dict().items()]

    def configure_fit(self, server_round: int, parameters, client_manager):
        self.round_num = server_round
        sample_size = min(self.config.num_clients, client_manager.num_available())
        clients = client_manager.sample(num_clients=sample_size, min_num_clients=sample_size)
        fit_configurations = []
        for client in clients:
            fit_configurations.append((client, fl.common.FitIns(parameters, {})))
        CLIENT_GAUGE.set(len(clients))
        return fit_configurations

    def aggregate_fit(self, server_round: int, results, failures):
        start_time = time.time()

        if not results:
            return None, {}

        weights_list = []
        for client, fit_res in results:
            weights = fl.common.parameters_to_ndarrays(fit_res.parameters)
            weights_list.append(weights)

        selected_indices = self._multi_krum_select(weights_list)
        byzantine_count = len(weights_list) - len(selected_indices)
        self.byzantine_detected += byzantine_count
        BYZANTINE_COUNTER.inc(byzantine_count)

        aggregated_weights = self._aggregate_weights([weights_list[i] for i in selected_indices])
        parameters_aggregated = fl.common.ndarrays_to_parameters(aggregated_weights)

        duration = time.time() - start_time
        ROUND_DURATION.observe(duration)
        ROUND_COUNTER.inc()

        return parameters_aggregated, {
            'num_clients': len(results),
            'num_selected': len(selected_indices),
            'num_byzantine_filtered': byzantine_count
        }

    def _multi_krum_select(self, weights_list: List[List[np.ndarray]]) -> List[int]:
        n = len(weights_list)
        m = self.config.num_byzantine

        flattened = [np.concatenate([w.flatten() for w in weights]) for weights in weights_list]
        distances = np.zeros((n, n))

        for i in range(n):
            for j in range(i + 1, n):
                dist = np.linalg.norm(flattened[i] - flattened[j])
                distances[i, j] = dist
                distances[j, i] = dist

        scores = []
        num_neighbors = n - m - 2
        for i in range(n):
            sorted_dists = np.sort(distances[i])
            score = np.sum(sorted_dists[1:num_neighbors+1])
            scores.append((score, i))

        scores.sort()
        num_selection = min(self.config.num_selection, n)
        return [idx for _, idx in scores[:num_selection]]

    def _aggregate_weights(self, weights_list: List[List[np.ndarray]]) -> List[np.ndarray]:
        n = len(weights_list)
        aggregated = []
        for layer_idx in range(len(weights_list[0])):
            layer_sum = np.zeros_like(weights_list[0][layer_idx])
            for weights in weights_list:
                layer_sum += weights[layer_idx]
            aggregated.append(layer_sum / n)
        return aggregated

    def configure_evaluate(self, server_round: int, parameters, client_manager):
        return []

    def aggregate_evaluate(self, server_round: int, results, failures):
        return None, {}

def save_checkpoint(model: nn.Module, round_num: int, bucket_name: str):
    try:
        s3 = boto3.client('s3')
        checkpoint_path = f'/tmp/model_round_{round_num}.pth'
        torch.save(model.state_dict(), checkpoint_path)
        s3_key = f'models/model_round_{round_num}.pth'
        s3.upload_file(checkpoint_path, bucket_name, s3_key)
        logger.info(f"Saved checkpoint to s3://{bucket_name}/{s3_key}")
    except Exception as e:
        logger.error(f"Failed to save checkpoint: {e}")

def main():
    logger.info("Starting Sovereign FL Aggregator")
    start_http_server(9090)

    model = MNISTNet()
    config = MultiKrumConfig(num_clients=200, num_byzantine=20, num_selection=180)
    strategy = MultiKrumStrategy(config, model)

    fl.server.start_server(
        server_address="0.0.0.0:8080",
        config=fl.server.ServerConfig(num_rounds=30),
        strategy=strategy
    )

if __name__ == "__main__":
    main()
EOF

# Create client.py
cat > client.py << 'EOF'
#!/usr/bin/env python3
"""Sovereign FL Client with differential privacy"""

import flwr as fl
import torch
import torch.nn as nn
import torch.nn.functional as F
from torchvision import datasets, transforms
from torch.utils.data import DataLoader, Subset
from opacus import PrivacyEngine
import argparse
import logging
import numpy as np

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class MNISTNet(nn.Module):
    def __init__(self):
        super(MNISTNet, self).__init__()
        self.conv1 = nn.Conv2d(1, 32, 3, 1)
        self.conv2 = nn.Conv2d(32, 64, 3, 1)
        self.fc1 = nn.Linear(9216, 128)
        self.fc2 = nn.Linear(128, 10)

    def forward(self, x):
        x = F.relu(self.conv1(x))
        x = F.relu(self.conv2(x))
        x = F.max_pool2d(x, 2)
        x = torch.flatten(x, 1)
        x = F.relu(self.fc1(x))
        x = self.fc2(x)
        return F.log_softmax(x, dim=1)

class SovereignClient(fl.client.NumPyClient):
    def __init__(self, node_id, byzantine=False):
        self.node_id = node_id
        self.byzantine = byzantine
        self.device = torch.device("cpu")
        self.model = MNISTNet().to(self.device)
        self.trainloader = self._load_data(node_id)
        self.optimizer = torch.optim.SGD(self.model.parameters(), lr=0.01)

        self.privacy_engine = PrivacyEngine()
        self.model, self.optimizer, self.trainloader = self.privacy_engine.make_private(
            module=self.model,
            optimizer=self.optimizer,
            data_loader=self.trainloader,
            noise_multiplier=1.1,
            max_grad_norm=1.0,
        )

    def _load_data(self, node_id):
        transform = transforms.Compose([
            transforms.ToTensor(),
            transforms.Normalize((0.1307,), (0.3081,))
        ])

        dataset = datasets.MNIST('./data', train=True, download=True, transform=transform)
        samples_per_node = len(dataset) // 200
        start_idx = node_id * samples_per_node
        end_idx = start_idx + samples_per_node

        subset = Subset(dataset, range(start_idx, end_idx))
        return DataLoader(subset, batch_size=32, shuffle=True)

    def get_parameters(self, config):
        return [val.cpu().numpy() for _, val in self.model.state_dict().items()]

    def set_parameters(self, parameters):
        params_dict = zip(self.model.state_dict().keys(), parameters)
        state_dict = {k: torch.tensor(v) for k, v in params_dict}
        self.model.load_state_dict(state_dict, strict=True)

    def fit(self, parameters, config):
        self.set_parameters(parameters)
        self.model.train()

        for epoch in range(3):
            for data, target in self.trainloader:
                data, target = data.to(self.device), target.to(self.device)
                self.optimizer.zero_grad()
                output = self.model(data)
                loss = F.nll_loss(output, target)
                loss.backward()
                self.optimizer.step()

        epsilon = self.privacy_engine.get_epsilon(delta=1e-5)
        logger.info(f"Node {self.node_id}: Training complete, epsilon={epsilon:.2f}")

        updated_params = self.get_parameters(config)

        if self.byzantine:
            updated_params = [-p for p in updated_params]
            logger.warning(f"Node {self.node_id}: Sent BYZANTINE update")

        return updated_params, len(self.trainloader.dataset), {}

    def evaluate(self, parameters, config):
        return 0.0, 0, {}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--node-id', type=int, required=True)
    parser.add_argument('--aggregator', type=str, required=True)
    parser.add_argument('--byzantine', action='store_true')
    args = parser.parse_args()

    client = SovereignClient(node_id=args.node_id, byzantine=args.byzantine)

    fl.client.start_numpy_client(
        server_address=args.aggregator,
        client=client
    )

if __name__ == "__main__":
    main()
EOF

# Create requirements.txt
cat > requirements.txt << 'EOF'
flwr>=1.5.0
torch>=2.0.0
torchvision>=0.15.0
opacus>=1.4.0
prometheus-client>=0.17.0
boto3>=1.28.0
numpy>=1.24.0
requests>=2.31.0
EOF

cd ..

echo "✓ Code bundle prepared in: code-bundle/"
echo ""

#================================================================================
# PHASE 3.2: UPLOAD TO S3
#================================================================================

echo "Step 3.2: Uploading code to S3..."

# Create code folder in S3
aws s3api put-object --bucket ${S3_BUCKET} --key "code/"

# Upload files
aws s3 cp code-bundle/aggregator.py s3://${S3_BUCKET}/code/
aws s3 cp code-bundle/client.py s3://${S3_BUCKET}/code/
aws s3 cp code-bundle/requirements.txt s3://${S3_BUCKET}/code/

# Create version marker
echo "$(date)" | aws s3 cp - s3://${S3_BUCKET}/code/deployed-at.txt

echo "✓ Code uploaded to s3://${S3_BUCKET}/code/"
echo ""

#================================================================================
# PHASE 3.3: DEPLOY TO AGGREGATOR
#================================================================================

echo "Step 3.3: Deploying to aggregator..."

# Wait for aggregator to be ready
echo "Waiting for aggregator SSH to be available..."
for i in {1..30}; do
    if ssh -i ~/.ssh/${KEY_NAME}.pem -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@${AGGREGATOR_PUBLIC_IP} "echo 'ready'" 2>/dev/null; then
        echo "✓ Aggregator is ready"
        break
    fi
    echo "Attempt $i/30: Waiting for SSH..."
    sleep 10
done

# Install dependencies on aggregator
echo "Installing dependencies on aggregator..."
ssh -i ~/.ssh/${KEY_NAME}.pem -o StrictHostKeyChecking=no ubuntu@${AGGREGATOR_PUBLIC_IP} << 'REMOTECMD'
    sudo apt-get update
    sudo apt-get install -y python3-pip
    pip3 install torch torchvision flwr opacus prometheus-client boto3

    # Download code from S3
    aws s3 cp s3://${S3_BUCKET}/code/ /opt/sovereign-fl/ --recursive

    echo "Dependencies installed at $(date)" | sudo tee /var/log/setup-complete.log
REMOTECMD

echo "✓ Aggregator configured"
echo ""

#================================================================================
# PHASE 3.4: VERIFY CLIENT NODES
#================================================================================

echo "Step 3.4: Verifying client nodes..."

# Wait for all client nodes to be ready
echo "Waiting for client nodes to initialize (this may take 5-10 minutes)..."
sleep 300

# Check how many instances are running
RUNNING_COUNT=$(aws ec2 describe-instances     --filters "Name=tag:Name,Values=sovereign-client" "Name=instance-state-name,Values=running"     --query 'length(Reservations[].Instances[])'     --output text)

echo "Running client nodes: $RUNNING_COUNT / 200"

#================================================================================
# PHASE 3 COMPLETE
#================================================================================

echo ""
echo "=========================================="
echo "PHASE 3 COMPLETE: Code Deployed"
echo "=========================================="
echo ""
echo "Summary:"
echo "  ✓ Code uploaded to S3"
echo "  ✓ Aggregator configured"
echo "  ✓ Client nodes initializing"
echo ""
echo "Next Steps:"
echo "  1. Run Phase 4: Test Execution"
echo "  2. Run: ./phase-4-execute-test.sh"
echo ""
