# Thinker Clauses Configuration (Edge Cases)

This document explains how to represent Thinker Clauses in `capabilities.json` to preserve minority and outlier paths without violating safety constraints.

## Suggested schema

```json
"thinker_clauses": {
  "enabled": true,
  "preserve_outliers": true,
  "minority_retention_min": 0.05,
  "minority_retention_max": 0.2,
  "outlier_distance_zscore_cap": 4.0,
  "manual_review_required_above_zscore": 3.5,
  "escalation_label": "thinker-review"
}
```

## Field guidance

- `enabled`: Gate for policy activation.
- `preserve_outliers`: If true, the runtime should retain a bounded minority slice instead of fully pruning outliers.
- `minority_retention_min`: Lower bound for retained minority fraction.
- `minority_retention_max`: Upper safety cap to avoid destabilizing training.
- `outlier_distance_zscore_cap`: Hard reject threshold for clearly malformed updates.
- `manual_review_required_above_zscore`: Values above this should be routed for human review.
- `escalation_label`: Queue/topic used by governance and recourse workflows.

## Edge cases and recommendations

- Data poisoning suspicion:
  Use a narrower retention band (for example 0.05 to 0.10), lower z-score caps, and mandatory manual review.

- Sparse regional shards:
  Increase `minority_retention_max` (for example up to 0.25) to avoid suppressing underrepresented cohorts.

- High heterogeneity rounds:
  Keep `preserve_outliers=true`, but enforce review for elevated z-scores to separate legitimate novelty from adversarial drift.

- Compliance freeze windows:
  Keep clauses enabled but temporarily lower `minority_retention_max` and route all retained outliers to audited review queues.

## Validation rule of thumb

Maintain Theorem 1 safety posture by keeping byzantine filtering active and bounded. Thinker clauses should preserve candidate paths, not bypass trust checks.
