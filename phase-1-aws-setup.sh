#!/bin/bash
#================================================================================
# COMPREHENSIVE AWS SETUP GUIDE - 200 NODE FL TEST
# Phase 1: Initial AWS Account Setup and Configuration
#================================================================================

# PHASE 1.1: AWS CLI INSTALLATION AND CONFIGURATION
#--------------------------------------------------------------------------------

echo "=========================================="
echo "PHASE 1: AWS Account Setup"
echo "=========================================="

# Install AWS CLI (if not already installed)
if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
fi

# Verify installation
aws --version

# Configure AWS credentials
echo ""
echo "Configuring AWS credentials..."
echo "You will need:"
echo "  - AWS Access Key ID"
echo "  - AWS Secret Access Key"
echo "  - Default region (us-east-1 recommended)"
echo "  - Output format (json recommended)"
echo ""

aws configure

# Verify configuration
aws sts get-caller-identity

#================================================================================
# PHASE 1.2: REQUEST SERVICE QUOTA INCREASES
#================================================================================

echo ""
echo "=========================================="
echo "Requesting Service Quota Increases"
echo "=========================================="

# Check current EC2 vCPU limits
echo "Current EC2 limits:"
aws service-quotas get-service-quota     --service-code ec2     --quota-code L-1216C47A     --region us-east-1

# Request increase to 250 vCPUs (for 200 t3.medium + 1 c5.2xlarge)
echo ""
echo "Requesting vCPU limit increase to 250..."
aws service-quotas request-quota-increase     --service-code ec2     --quota-code L-1216C47A     --desired-value 250     --region us-east-1

# Note: This request takes 24-48 hours to approve
# You can check status in AWS Console → Service Quotas

echo ""
echo "⚠️  IMPORTANT: Service quota increase requested."
echo "Check status in AWS Console → Service Quotas → Request history"
echo "Wait for approval before proceeding to Phase 2."
echo ""

#================================================================================
# PHASE 1.3: CREATE S3 BUCKET FOR RESULTS
#================================================================================

echo ""
echo "=========================================="
echo "Creating S3 Bucket for Test Results"
echo "=========================================="

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="sovereign-fl-results-${ACCOUNT_ID}"
REGION="us-east-1"

# Create bucket
echo "Creating bucket: ${BUCKET_NAME}"
aws s3 mb "s3://${BUCKET_NAME}" --region ${REGION}

# Enable versioning
aws s3api put-bucket-versioning     --bucket ${BUCKET_NAME}     --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption     --bucket ${BUCKET_NAME}     --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'

# Create folder structure
echo "Creating folder structure..."
aws s3api put-object --bucket ${BUCKET_NAME} --key "tests/"
aws s3api put-object --bucket ${BUCKET_NAME} --key "models/"
aws s3api put-object --bucket ${BUCKET_NAME} --key "logs/"
aws s3api put-object --bucket ${BUCKET_NAME} --key "metrics/"
aws s3api put-object --bucket ${BUCKET_NAME} --key "reports/"

echo ""
echo "✓ S3 bucket created: ${BUCKET_NAME}"
echo ""

#================================================================================
# PHASE 1.4: CREATE EC2 KEY PAIR
#================================================================================

echo ""
echo "=========================================="
echo "Creating EC2 Key Pair"
echo "=========================================="

KEY_NAME="sovereign-fl-key"

# Create key pair
aws ec2 create-key-pair     --key-name ${KEY_NAME}     --key-type rsa     --key-format pem     --query "KeyMaterial"     --output text > "${KEY_NAME}.pem"

# Set permissions
chmod 400 "${KEY_NAME}.pem"

# Move to .ssh directory
mkdir -p ~/.ssh
mv "${KEY_NAME}.pem" ~/.ssh/

echo "✓ Key pair created: ${KEY_NAME}"
echo "Location: ~/.ssh/${KEY_NAME}.pem"
echo ""

#================================================================================
# PHASE 1.5: SETUP IAM ROLE FOR EC2 INSTANCES
#================================================================================

echo ""
echo "=========================================="
echo "Setting up IAM Role for EC2"
echo "=========================================="

ROLE_NAME="SovereignFL-EC2-Role"

# Create trust policy
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create role
aws iam create-role     --role-name ${ROLE_NAME}     --assume-role-policy-document file://trust-policy.json

# Attach policies
aws iam attach-role-policy     --role-name ${ROLE_NAME}     --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

aws iam attach-role-policy     --role-name ${ROLE_NAME}     --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy

# Create instance profile
aws iam create-instance-profile --instance-profile-name ${ROLE_NAME}

# Add role to instance profile
aws iam add-role-to-instance-profile     --instance-profile-name ${ROLE_NAME}     --role-name ${ROLE_NAME}

rm trust-policy.json

echo "✓ IAM role created: ${ROLE_NAME}"
echo ""

#================================================================================
# PHASE 1.6: SETUP CLOUDWATCH LOGS
#================================================================================

echo ""
echo "=========================================="
echo "Setting up CloudWatch Logs"
echo "=========================================="

# Create log groups
aws logs create-log-group --log-group-name "/sovereign-fl/aggregator"
aws logs create-log-group --log-group-name "/sovereign-fl/clients"

# Set retention (7 days)
aws logs put-retention-policy     --log-group-name "/sovereign-fl/aggregator"     --retention-in-days 7

aws logs put-retention-policy     --log-group-name "/sovereign-fl/clients"     --retention-in-days 7

echo "✓ CloudWatch Logs configured"
echo ""

#================================================================================
# PHASE 1.7: SAVE CONFIGURATION
#================================================================================

echo ""
echo "=========================================="
echo "Saving Configuration"
echo "=========================================="

cat > aws-config.env << EOF
# Sovereign FL 200-Node Test Configuration
# Generated: $(date)

AWS_REGION=${REGION}
AWS_ACCOUNT_ID=${ACCOUNT_ID}
S3_BUCKET=${BUCKET_NAME}
KEY_NAME=${KEY_NAME}
IAM_ROLE=${ROLE_NAME}
VPC_NAME=sovereign-fl-vpc
AGGREGATOR_INSTANCE_TYPE=c5.2xlarge
CLIENT_INSTANCE_TYPE=t3.medium
NODE_COUNT=200
EOF

echo "✓ Configuration saved to: aws-config.env"
echo ""

#================================================================================
# PHASE 1 COMPLETE
#================================================================================

echo ""
echo "=========================================="
echo "PHASE 1 COMPLETE: AWS Setup Finished"
echo "=========================================="
echo ""
echo "Summary:"
echo "  ✓ AWS CLI configured"
echo "  ✓ Service quota increase requested (wait for approval)"
echo "  ✓ S3 bucket created: ${BUCKET_NAME}"
echo "  ✓ EC2 key pair created: ${KEY_NAME}"
echo "  ✓ IAM role created: ${ROLE_NAME}"
echo "  ✓ CloudWatch Logs configured"
echo ""
echo "Next Steps:"
echo "  1. Wait for service quota approval (check email/AWS console)"
echo "  2. Run Phase 2: Infrastructure Deployment"
echo "  3. Run: ./phase-2-deploy-infrastructure.sh"
echo ""
echo "Configuration file: aws-config.env"
echo ""
