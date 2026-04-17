#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dataset="${DATASET:-${1:-}}"
input_csv="${INPUT_CSV:-}"
label_column="${LABEL_COLUMN:-}"
output="${OUTPUT:-results/demo/synthesize_bio/training_report.json}"
validation_profile="${VALIDATION_PROFILE:-fast}"
artifact_dir="${ARTIFACT_DIR:-results/demo/synthesize_bio/docker}"
image="${DEMO_RUNNER_IMAGE:-docker:27-cli}"
keep_stack="${KEEP_STACK:-0}"

if [[ -z "${dataset}" && -z "${input_csv}" ]]; then
	cat >&2 <<'EOF'
usage: DATASET=<dataset-url-or-uuid> [LABEL_COLUMN=name] [VALIDATION_PROFILE=fast] [OUTPUT=path] ./scripts/run_synthesizebio_demo_in_docker.sh
   or: INPUT_CSV=<path-to-export.csv> [LABEL_COLUMN=name] [VALIDATION_PROFILE=fast] [OUTPUT=path] ./scripts/run_synthesizebio_demo_in_docker.sh
EOF
	exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
	echo "docker is required but not installed" >&2
	exit 1
fi

if ! docker info >/dev/null 2>&1; then
	echo "docker daemon is not reachable" >&2
	exit 1
fi

mkdir -p "${repo_root}/${artifact_dir}"

docker run --rm \
	-v "${repo_root}:/workspace" \
	-v /var/run/docker.sock:/var/run/docker.sock \
	-w /workspace \
	-e DATASET="${dataset}" \
	-e INPUT_CSV="${input_csv}" \
	-e LABEL_COLUMN="${label_column}" \
	-e OUTPUT="${output}" \
	-e VALIDATION_PROFILE="${validation_profile}" \
	-e ARTIFACT_DIR="${artifact_dir}" \
	-e KEEP_STACK="${keep_stack}" \
	"${image}" \
	sh -lc 'apk add --no-cache bash python3 py3-pip make curl openssl >/dev/null && exec bash /workspace/scripts/run_synthesizebio_demo_in_docker_inner.sh'
