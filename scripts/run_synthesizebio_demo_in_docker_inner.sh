#!/usr/bin/env bash
set -euo pipefail

if ! docker compose version >/dev/null 2>&1; then
	echo "docker compose v2 is required inside the helper container" >&2
	exit 1
fi

run_id="$(date -u +%Y%m%dT%H%M%SZ)"
run_dir="${ARTIFACT_DIR}/${run_id}"
mkdir -p "${run_dir}"
log_file="${run_dir}/demo.log"
summary_file="${run_dir}/manifest.json"

exec > >(tee -a "${log_file}") 2>&1

run_step() {
	local name="$1"
	shift
	echo "[demo] ${name}"
	"$@"
}

copy_if_exists() {
	for path in "$@"; do
		if [[ -e "$path" ]]; then
			cp -a "$path" "${run_dir}/"
		fi
	done
}

cleanup() {
	if [[ "${KEEP_STACK}" != "1" ]]; then
		./scripts/launch_full_stack_3_nodes.sh --down >/dev/null 2>&1 || true
	fi
}
trap cleanup EXIT

run_step "launch stack" ./scripts/launch_full_stack_3_nodes.sh --no-build

if [[ -n "${INPUT_CSV}" ]]; then
	run_step "train synthesize.bio dataset export" env INPUT_CSV="${INPUT_CSV}" LABEL_COLUMN="${LABEL_COLUMN}" OUTPUT="${OUTPUT}" ./scripts/run_synthesizebio_demo.sh
else
	run_step "train synthesize.bio dataset export" env DATASET="${DATASET}" LABEL_COLUMN="${LABEL_COLUMN}" OUTPUT="${OUTPUT}" ./scripts/run_synthesizebio_demo.sh
fi

run_step "release performance evidence" make release-performance-evidence
run_step "advisory go-live gate" make go-live-gate-advisory

case "${VALIDATION_PROFILE}" in
	fast)
		run_step "full validation fast" make full-validation-fast
		;;
	deep)
		run_step "full validation deep" make full-validation-deep
		;;
	go-live)
		run_step "golden path e2e" make golden-path-e2e
		run_step "full validation fast" make full-validation-fast
		;;
	*)
		echo "unsupported VALIDATION_PROFILE: ${VALIDATION_PROFILE}" >&2
		exit 1
		;;
esac

copy_if_exists \
	"${OUTPUT}" \
	results/go-live/golden-path-report.json \
	results/go-live/golden-path-report.md \
	results/metrics/release_performance_evidence.md \
	results/metrics/accelerator_backend_compare.json \
	results/metrics/accelerator_backend_compare.md

latest_validation_json="$(ls -1t test-results/full-validation/full_validation_*.json 2>/dev/null | head -n 1 || true)"
latest_validation_md="$(ls -1t test-results/full-validation/full_validation_*.md 2>/dev/null | head -n 1 || true)"
if [[ -n "${latest_validation_json}" ]]; then
	cp -a "${latest_validation_json}" "${run_dir}/"
fi
if [[ -n "${latest_validation_md}" ]]; then
	cp -a "${latest_validation_md}" "${run_dir}/"
fi

docker ps --format 'table {{.Names}}\t{{.Status}}' > "${run_dir}/docker-ps.txt"
docker compose -f docker-compose.yml ps > "${run_dir}/compose-ps.txt" || true

cat > "${summary_file}" <<EOF
{
  "dataset": "${DATASET}",
  "input_csv": "${INPUT_CSV}",
  "label_column": "${LABEL_COLUMN}",
  "output": "${OUTPUT}",
  "validation_profile": "${VALIDATION_PROFILE}",
  "artifact_dir": "${run_dir}",
  "kept_stack": ${KEEP_STACK}
}
EOF

echo "[demo] artifacts saved to ${run_dir}"
