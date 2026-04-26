# Cloud Quickstart Templates (Scaffold)

These templates are starter assets for one-click VM bootstrap paths on AWS and GCP.

## Files

- `aws-userdata.sh`: EC2 user-data bootstrap script.
- `gcp-startup.sh`: GCE startup script.

## Usage (AWS)

```bash
aws ec2 run-instances \
  --image-id <ami-id> \
  --instance-type t3.large \
  --user-data file://deploy/cloud-templates/aws-userdata.sh
```

## Usage (GCP)

```bash
gcloud compute instances create mohawk-node-1 \
  --machine-type=e2-standard-4 \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --metadata-from-file startup-script=deploy/cloud-templates/gcp-startup.sh
```

## What the scripts do

- Install Docker + Git.
- Clone this repository.
- Launch the baseline stack (`orchestrator`, `node-agent-1`, `prometheus`, `grafana`).
- Print post-boot health commands.

These are scaffolds meant for rapid evaluation. For hardened production use, pair them with the Helm chart and cloud-native IAM/network controls.
