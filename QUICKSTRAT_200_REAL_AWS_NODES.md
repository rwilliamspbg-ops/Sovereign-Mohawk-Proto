Sovereign FL 200-Node Test - Quick Start
Run Complete Test (5 phases)
bash
Copy
# 1. Setup AWS (one-time)
./run-test.sh setup

# 2. Deploy infrastructure (200 EC2 instances)
./run-test.sh deploy

# 3. Deploy code
./run-test.sh code

# 4. Run test (3 hours)
./run-test.sh test

# 5. Capture results
./run-test.sh results

# 6. Cleanup (when done)
./run-test.sh cleanup
Or run everything at once
bash
Copy
./run-test.sh all
Check status anytime
bash
Copy
./run-test.sh status
./run-test.sh logs
./run-test.sh dashboard
Files Created
Table
Copy
File	Purpose
run-test.sh	Master orchestration script
phase-1-aws-setup.sh	AWS account setup
phase-2-deploy-infrastructure.sh	Terraform deployment
phase-3-deploy-code.sh	Code upload & install
phase-4-execute-test.sh	Run FL training
phase-5-capture-results.sh	Generate reports
phase-6-cleanup.sh	Destroy infrastructure
terraform/	Infrastructure as Code
src/	Python FL code
Cost
Per test: ~$20 (3 hours)
Monthly (weekly): ~$80
Full Documentation
See individual phase scripts for detailed walkthroughs.
