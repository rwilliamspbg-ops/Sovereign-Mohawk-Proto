#!/bin/bash
#================================================================================
# PHASE 2: INFRASTRUCTURE DEPLOYMENT
# Deploy 200 EC2 instances with networking, security, and monitoring
#================================================================================

set -e

echo "=========================================="
echo "PHASE 2: Infrastructure Deployment"
echo "=========================================="

# Load configuration
if [[ -f aws-config.env ]]; then
    source aws-config.env
else
    echo "Error: aws-config.env not found. Run Phase 1 first."
    exit 1
fi

#================================================================================
# PHASE 2.1: TERRAFORM INITIALIZATION
#================================================================================

echo ""
echo "Step 2.1: Initializing Terraform..."

# Create Terraform directory structure
mkdir -p terraform
cd terraform

# Create backend configuration
cat > backend.tf << 'EOF'
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "sovereign-fl-terraform-state"
    key    = "200-node-test/terraform.tfstate"
    region = "us-east-1"
  }
}
EOF

# Create variables file
cat > variables.tf << EOF
variable "aws_region" {
  description = "AWS region"
  default     = "${AWS_REGION}"
}

variable "node_count" {
  description = "Number of client nodes"
  default     = ${NODE_COUNT}
}

variable "key_pair_name" {
  description = "EC2 key pair name"
  default     = "${KEY_NAME}"
}

variable "iam_role" {
  description = "IAM role for EC2 instances"
  default     = "${IAM_ROLE}"
}
EOF

# Create main Terraform configuration
cat > main.tf << 'MAINEOF'
# Data source for Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

# Get current caller identity
data "aws_caller_identity" "current" {}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "sovereign-fl-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "sovereign-fl-vpc"
    Project = "Sovereign-FL-200-Node-Test"
  }
}

# Security Group for Aggregator
resource "aws_security_group" "aggregator" {
  name_prefix = "sovereign-aggregator-"
  description = "Security group for FL aggregator"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH from admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Flower server"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sovereign-aggregator"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for Clients
resource "aws_security_group" "client" {
  name_prefix = "sovereign-client-"
  description = "Security group for FL client nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH from admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sovereign-client"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# S3 Bucket for checkpoints
resource "aws_s3_bucket" "checkpoints" {
  bucket = "sovereign-fl-checkpoints-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "sovereign-fl-checkpoints"
  }
}

resource "aws_s3_bucket_versioning" "checkpoints" {
  bucket = aws_s3_bucket.checkpoints.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Aggregator EC2 Instance
resource "aws_instance" "aggregator" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "c5.2xlarge"
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.aggregator.id]
  subnet_id              = module.vpc.public_subnets[0]
  iam_instance_profile   = var.iam_role

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  user_data = <<-EOF
    #!/bin/bash
    exec > >(tee /var/log/user-data.log) 2>&1

    # Update system
    apt-get update
    apt-get upgrade -y

    # Install Docker
    apt-get install -y docker.io
    systemctl enable docker
    usermod -aG docker ubuntu

    # Install Python & dependencies
    apt-get install -y python3-pip python3-venv
    pip3 install torch torchvision flwr opacus prometheus-client boto3

    # Create working directory
    mkdir -p /opt/sovereign-fl
    cd /opt/sovereign-fl

    # Download code from S3 (will be uploaded in Phase 3)
    aws s3 cp s3://${aws_s3_bucket.checkpoints.bucket}/code/aggregator.py .
    aws s3 cp s3://${aws_s3_bucket.checkpoints.bucket}/code/client.py .

    # Start Prometheus
    docker run -d -p 9090:9090 --name prometheus prom/prometheus

    # Start Grafana
    docker run -d -p 3000:3000 --name grafana grafana/grafana

    echo "Setup complete at $(date)" >> /var/log/setup.log
  EOF

  tags = {
    Name = "sovereign-aggregator"
    Role = "fl-aggregator"
  }
}

# Elastic IP for aggregator
resource "aws_eip" "aggregator" {
  instance = aws_instance.aggregator.id
  domain   = "vpc"

  tags = {
    Name = "sovereign-aggregator-eip"
  }
}

# Launch Template for Client Nodes
resource "aws_launch_template" "client" {
  name_prefix   = "sovereign-client-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"
  key_name      = var.key_pair_name

  iam_instance_profile {
    name = var.iam_role
  }

  vpc_security_group_ids = [aws_security_group.client.id]

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 20
      volume_type = "gp3"
    }
  }

  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price                      = "0.05"
      spot_instance_type             = "one-time"
      instance_interruption_behavior = "terminate"
    }
  }

  monitoring {
    enabled = true
  }

  user_data = <<-EOF
    #!/bin/bash
    exec > >(tee /var/log/user-data.log) 2>&1

    apt-get update
    apt-get install -y python3-pip awscli

    pip3 install torch torchvision flwr opacus

    mkdir -p /opt/sovereign-fl
    cd /opt/sovereign-fl

    aws s3 cp s3://${aws_s3_bucket.checkpoints.bucket}/code/client.py .

    echo "Client ready at $(date)" >> /var/log/setup.log
  EOF

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "sovereign-client"
      Role = "fl-client"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group for 200 Client Nodes
resource "aws_autoscaling_group" "clients" {
  name                = "sovereign-fl-clients"
  vpc_zone_identifier = module.vpc.private_subnets
  health_check_type   = "EC2"
  health_check_grace_period = 300

  min_size         = var.node_count
  max_size         = var.node_count
  desired_capacity = var.node_count

  launch_template {
    id      = aws_launch_template.client.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "sovereign-client"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = "Sovereign-FL-200-Node-Test"
    propagate_at_launch = true
  }

  depends_on = [aws_instance.aggregator]
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "sovereign_fl" {
  dashboard_name = "Sovereign-FL-200-Node-Test"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Connected Clients"
          region = "us-east-1"
          metrics = [
            ["SovereignFL", "ConnectedClients", { stat = "Average" }]
          ]
          period = 60
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Model Accuracy"
          region = "us-east-1"
          metrics = [
            ["SovereignFL", "ModelAccuracy", { stat = "Average" }]
          ]
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "Byzantine Nodes Detected"
          region = "us-east-1"
          metrics = [
            ["SovereignFL", "ByzantineDetected", { stat = "Sum" }]
          ]
          period = 60
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "FL Rounds Completed"
          region = "us-east-1"
          metrics = [
            ["SovereignFL", "FLRounds", { stat = "Sum" }]
          ]
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "Training Loss"
          region = "us-east-1"
          metrics = [
            ["SovereignFL", "TrainingLoss", { stat = "Average" }]
          ]
          period = 300
        }
      }
    ]
  })
}

# Outputs
output "aggregator_public_ip" {
  description = "Public IP of the aggregator node"
  value       = aws_eip.aggregator.public_ip
}

output "aggregator_private_ip" {
  description = "Private IP of the aggregator node"
  value       = aws_instance.aggregator.private_ip
}

output "s3_bucket_name" {
  description = "S3 bucket for checkpoints"
  value       = aws_s3_bucket.checkpoints.bucket
}

output "cloudwatch_dashboard_url" {
  description = "URL to CloudWatch dashboard"
  value       = "https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=${aws_cloudwatch_dashboard.sovereign_fl.dashboard_name}"
}

output "ssh_command" {
  description = "SSH command to connect to aggregator"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_eip.aggregator.public_ip}"
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "http://${aws_eip.aggregator.public_ip}:3000"
}

output "prometheus_url" {
  description = "Prometheus metrics URL"
  value       = "http://${aws_eip.aggregator.public_ip}:9090"
}
MAINEOF

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Create S3 bucket for Terraform state (if not exists)
STATE_BUCKET="sovereign-fl-terraform-state-${AWS_ACCOUNT_ID}"

if ! aws s3api head-bucket --bucket "$STATE_BUCKET" 2>/dev/null; then
    echo "Creating Terraform state bucket: $STATE_BUCKET"
    aws s3 mb "s3://$STATE_BUCKET" --region $AWS_REGION
    aws s3api put-bucket-versioning         --bucket "$STATE_BUCKET"         --versioning-configuration Status=Enabled
fi

echo ""
echo "✓ Terraform initialized"
echo ""

#================================================================================
# PHASE 2.2: TERRAFORM PLAN
#================================================================================

echo "Step 2.2: Planning deployment..."

terraform plan -out=tfplan

echo ""
echo "✓ Terraform plan created: tfplan"
echo ""

#================================================================================
# PHASE 2.3: TERRAFORM APPLY
#================================================================================

echo "Step 2.3: Deploying infrastructure..."
echo ""
echo "⚠️  This will create:"
echo "  - 1 VPC with 3 AZs"
echo "  - 1 Aggregator (c5.2xlarge)"
echo "  - 200 Client nodes (t3.medium spot)"
echo "  - S3 bucket for checkpoints"
echo "  - CloudWatch dashboard"
echo ""
echo "Estimated cost: $16-25 for 3-hour test"
echo ""

read -p "Continue with deployment? (yes/no): " confirm
if [[ $confirm != "yes" ]]; then
    echo "Deployment cancelled"
    exit 0
fi

terraform apply tfplan

#================================================================================
# PHASE 2.4: CAPTURE OUTPUTS
#================================================================================

echo ""
echo "Step 2.4: Capturing deployment outputs..."

AGGREGATOR_IP=$(terraform output -raw aggregator_public_ip)
AGGREGATOR_PRIVATE_IP=$(terraform output -raw aggregator_private_ip)
S3_BUCKET=$(terraform output -raw s3_bucket_name)
GRAFANA_URL=$(terraform output -raw grafana_url)
PROMETHEUS_URL=$(terraform output -raw prometheus_url)
SSH_CMD=$(terraform output -raw ssh_command)

echo ""
echo "=========================================="
echo "DEPLOYMENT COMPLETE"
echo "=========================================="
echo ""
echo "Aggregator Public IP:  $AGGREGATOR_IP"
echo "Aggregator Private IP: $AGGREGATOR_PRIVATE_IP"
echo "S3 Bucket:            $S3_BUCKET"
echo "Grafana:              $GRAFANA_URL"
echo "Prometheus:           $PROMETHEUS_URL"
echo "SSH Command:          $SSH_CMD"
echo ""

# Save outputs
cat > ../deployment-outputs.env << EOF
# Deployment Outputs
# Generated: $(date)

AGGREGATOR_PUBLIC_IP=${AGGREGATOR_IP}
AGGREGATOR_PRIVATE_IP=${AGGREGATOR_PRIVATE_IP}
S3_BUCKET=${S3_BUCKET}
GRAFANA_URL=${GRAFANA_URL}
PROMETHEUS_URL=${PROMETHEUS_URL}
SSH_COMMAND=${SSH_CMD}
EOF

echo "Outputs saved to: deployment-outputs.env"
echo ""

#================================================================================
# PHASE 2.5: VERIFY DEPLOYMENT
#================================================================================

echo "Step 2.5: Verifying deployment..."

# Check EC2 instances
echo "Checking EC2 instances..."
aws ec2 describe-instances     --filters "Name=tag:Project,Values=Sovereign-FL-200-Node-Test"     --query 'Reservations[*].Instances[*].{ID:InstanceId,Type:InstanceType,State:State.Name,Name:Tags[?Key==\`Name\`]|[0].Value}'     --output table

# Check Auto Scaling Group
echo ""
echo "Checking Auto Scaling Group..."
aws autoscaling describe-auto-scaling-groups     --auto-scaling-group-names sovereign-fl-clients     --query 'AutoScalingGroups[0].{Name:AutoScalingGroupName,Desired:DesiredCapacity,Instances:length(Instances),Status:Status}'     --output table

echo ""
echo "=========================================="
echo "PHASE 2 COMPLETE: Infrastructure Deployed"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "  1. Wait 5 minutes for instances to initialize"
echo "  2. Run Phase 3: Code Deployment"
echo "  3. Run: ../phase-3-deploy-code.sh"
echo ""
echo "Monitor in AWS Console:"
echo "  - EC2 Dashboard: https://console.aws.amazon.com/ec2/"
echo "  - CloudWatch Dashboard: $(terraform output -raw cloudwatch_dashboard_url)"
echo ""
