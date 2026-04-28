package metrics

import (
	"strings"

	"github.com/prometheus/client_golang/prometheus"
)

var (
	tpmQuotesTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "mohawk_tpm_quotes_total",
			Help: "Total TPM quote generation attempts.",
		},
		[]string{"result"},
	)
	tpmVerificationsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "mohawk_tpm_verifications_total",
			Help: "Total TPM attestation verification attempts.",
		},
		[]string{"result"},
	)
	consensusHonestRatio = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "mohawk_consensus_honest_ratio",
			Help: "Observed honest ratio for a shard or round.",
		},
		[]string{"scope"},
	)
	hierarchicalLevels = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "mohawk_hva_levels",
			Help: "Number of HVA hierarchy levels for a given scope.",
		},
		[]string{"scope"},
	)
	ipfsOperationsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "mohawk_ipfs_operations_total",
			Help: "Total IPFS checkpoint operations.",
		},
		[]string{"operation", "result"},
	)

	// Accelerator metrics -------------------------------------------------------

	// gradientCompressionRatio tracks the wire-size reduction achieved by
	// FP16/INT8 quantization. Buckets represent ratio multiples (1x → 4x).
	gradientCompressionRatio = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "mohawk_gradient_compression_ratio",
			Help:    "Ratio of uncompressed to compressed gradient bytes (higher = better).",
			Buckets: []float64{1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0},
		},
		[]string{"format"}, // "fp16" | "int8"
	)

	// acceleratorOpsTotal counts completed accelerator operations per device backend.
	acceleratorOpsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "mohawk_accelerator_ops_total",
			Help: "Total hardware-accelerated operations completed.",
		},
		[]string{"backend", "operation", "result"}, // backend: cpu|cuda|metal|npu
	)

	// acceleratorOpLatency records operation latency in milliseconds.
	acceleratorOpLatency = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "mohawk_accelerator_op_latency_ms",
			Help:    "Latency of accelerator operations in milliseconds.",
			Buckets: []float64{0.1, 0.5, 1, 2, 5, 10, 20, 50, 100, 250},
		},
		[]string{"backend", "operation"},
	)

	// proofBatchSize records how many proofs are verified in each batch call.
	proofBatchSize = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "mohawk_proof_batch_size",
			Help:    "Number of zk-SNARK proofs verified per BatchVerifyProofs call.",
			Buckets: prometheus.ExponentialBuckets(1, 2, 10), // 1,2,4,…,512
		},
		[]string{"result"},
	)

	// aggregationWorkers tracks the GOMAXPROCS-equivalent worker count used for
	// parallel gradient aggregation.
	aggregationWorkers = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "mohawk_aggregation_workers",
		Help: "Number of parallel workers used for the most recent gradient aggregation.",
	})

	// utilityCoinMintsTotal counts successful utility coin mint operations.
	utilityCoinMintsTotal = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "mohawk_utility_coin_mints_total",
		Help: "Total successful utility coin mint operations.",
	})

	// utilityCoinTransfersTotal counts successful utility coin transfers.
	utilityCoinTransfersTotal = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "mohawk_utility_coin_transfers_total",
		Help: "Total successful utility coin transfer operations.",
	})

	// utilityCoinMintedAmountTotal accumulates all minted utility coin amounts.
	utilityCoinMintedAmountTotal = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "mohawk_utility_coin_minted_amount_total",
		Help: "Cumulative minted utility coin amount.",
	})

	// utilityCoinTransferredAmountTotal accumulates all transferred utility coin amounts.
	utilityCoinTransferredAmountTotal = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "mohawk_utility_coin_transferred_amount_total",
		Help: "Cumulative transferred utility coin amount.",
	})

	// utilityCoinTotalSupply tracks the latest observed total utility coin supply.
	utilityCoinTotalSupply = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "mohawk_utility_coin_total_supply",
		Help: "Latest observed utility coin total supply.",
	})

	// utilityCoinTxCount tracks the latest observed utility coin ledger transaction count.
	utilityCoinTxCount = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "mohawk_utility_coin_tx_count",
		Help: "Latest observed utility coin ledger transaction count.",
	})

	// utilityCoinBurnsTotal counts successful utility coin burn operations.
	utilityCoinBurnsTotal = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "mohawk_utility_coin_burns_total",
		Help: "Total successful utility coin burn operations.",
	})

	// utilityCoinBurnedAmountTotal accumulates all burned utility coin amounts.
	utilityCoinBurnedAmountTotal = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "mohawk_utility_coin_burned_amount_total",
		Help: "Cumulative burned utility coin amount.",
	})

	// utilityCoinHoldersCount tracks the number of unique accounts with a non-zero balance.
	utilityCoinHoldersCount = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "mohawk_utility_coin_holders_count",
		Help: "Number of unique accounts with a non-zero utility coin balance.",
	})

	// proofVerificationsTotal counts individual zk-SNARK proof verifications by scheme and outcome.
	proofVerificationsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "mohawk_proof_verifications_total",
			Help: "Total zk-proof verification attempts by scheme and result.",
		},
		[]string{"scheme", "result"}, // scheme: groth16 | fri | winterfell | hybrid
	)

	// proofVerificationLatency records individual proof verification latency in milliseconds.
	proofVerificationLatency = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "mohawk_proof_verification_latency_ms",
			Help:    "Proof verification latency in milliseconds by scheme.",
			Buckets: []float64{0.1, 0.5, 1, 2, 5, 10, 15, 20, 50},
		},
		[]string{"scheme"},
	)

	// proofVerificationP99 records the latency samples used to track p99 proof
	// verification behavior in Prometheus queries.
	proofVerificationP99 = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "mohawk_proof_verification_p99",
			Help:    "Proof verification latency samples used for p99 tracking.",
			Buckets: []float64{0.1, 0.5, 1, 2, 5, 10, 15, 20, 50, 100},
		},
		[]string{"scheme"},
	)

	// formalBFTResilienceEstimate records the observed honest-node ratio used as
	// the runtime BFT resilience estimate.
	formalBFTResilienceEstimate = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "mohawk_bft_resilience_estimate",
			Help: "Observed Byzantine resilience estimate for a scope.",
		},
		[]string{"scope"},
	)

	// formalRDPCompositionCurrent records the current composed epsilon budget.
	formalRDPCompositionCurrent = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "mohawk_rdp_composition_current",
			Help: "Current composed RDP epsilon for a scope.",
		},
		[]string{"scope"},
	)

	// formalCommunicationCostObserved records the current communication-cost
	// proxy used by the runtime aggregation path.
	formalCommunicationCostObserved = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "mohawk_communication_cost_observed",
			Help:    "Observed communication-cost proxy for a scope.",
			Buckets: []float64{1, 5, 10, 25, 50, 100, 250, 500, 1000, 5000},
		},
		[]string{"scope"},
	)

	// formalLivenessSuccessProbability records the live success probability used
	// by the runtime liveness monitor.
	formalLivenessSuccessProbability = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "mohawk_liveness_success_prob",
			Help: "Observed liveness success probability for a scope.",
		},
		[]string{"scope"},
	)

	// pqcPolicyEnabled exposes whether critical PQC controls are currently enforced.
	pqcPolicyEnabled = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "mohawk_pqc_policy_enabled",
			Help: "Boolean state (1/0) for critical PQC enforcement controls.",
		},
		[]string{"policy"},
	)

	// pqcPolicyModeInfo encodes active mode labels for runtime policy controls.
	pqcPolicyModeInfo = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "mohawk_pqc_policy_mode_info",
			Help: "Info metric exposing active policy mode labels (value is always 1).",
		},
		[]string{"policy", "mode"},
	)

	// pqcPolicyEpochUnix stores active epoch boundaries as unix timestamps.
	pqcPolicyEpochUnix = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "mohawk_pqc_policy_epoch_unix",
			Help: "Configured unix epoch value for PQC cutover controls.",
		},
		[]string{"policy"},
	)

	// thinkerClauseConfig surfaces thinker-clause governance knobs for policy verification.
	thinkerClauseConfig = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "mohawk_thinker_clause_config",
			Help: "Thinker-clause configuration values exported as gauges.",
		},
		[]string{"setting"},
	)

	// migrationRequestsTotal counts migration API requests by endpoint and result.
	migrationRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "mohawk_migration_requests_total",
			Help: "Total migration control-plane API requests by endpoint and result.",
		},
		[]string{"endpoint", "result"},
	)

	// migrationRequestLatency records migration API request latency in milliseconds.
	migrationRequestLatency = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "mohawk_migration_request_latency_ms",
			Help:    "Migration control-plane API request latency in milliseconds.",
			Buckets: []float64{0.5, 1, 2, 5, 10, 20, 50, 100, 250, 500},
		},
		[]string{"endpoint"},
	)

	// migrationSignaturePathTotal tracks usage and outcome of migration signing paths.
	migrationSignaturePathTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "mohawk_migration_signature_path_total",
			Help: "Total migration operations by signature path and result.",
		},
		[]string{"path", "result"},
	)

	// authzDenialsTotal records authorization denials for protected API paths.
	authzDenialsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "mohawk_authz_denials_total",
			Help: "Total authorization denials by endpoint and reason.",
		},
		[]string{"endpoint", "reason"},
	)

	// routerRequestsTotal records cross-vertical router endpoint outcomes.
	routerRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "mohawk_router_requests_total",
			Help: "Total router API requests by endpoint, result, and reason.",
		},
		[]string{"endpoint", "result", "reason"},
	)

	// routerProvenanceRecords tracks the latest observed provenance record count.
	routerProvenanceRecords = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "mohawk_router_provenance_records",
		Help: "Latest number of persisted router provenance records.",
	})

	// FedAvg Scaling Metrics ────────────────────────────────────────────────────

	// fedavgRoundDurationSeconds records round execution duration in seconds.
	fedavgRoundDurationSeconds = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "mohawk_fedavg_round_duration_seconds",
			Help:    "FedAvg round execution duration in seconds.",
			Buckets: []float64{0.1, 0.5, 1, 2, 5, 10, 20, 30, 60, 120},
		},
		[]string{"scenario", "tier"},
	)

	// fedavgParticipationRatio tracks the fraction of nodes that contributed in the round.
	fedavgParticipationRatio = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "mohawk_fedavg_participation_ratio",
			Help: "Fraction of active nodes / total nodes in the round [0.0, 1.0].",
		},
		[]string{"scenario", "tier"},
	)

	// fedavgStragglerCount tracks absolute count of nodes exceeding timeout.
	fedavgStragglerCount = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "mohawk_fedavg_straggler_count",
			Help: "Number of nodes lagging behind in current round.",
		},
		[]string{"scenario", "tier"},
	)

	// fedavgStragglerFraction tracks straggler_count / total_nodes.
	fedavgStragglerFraction = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "mohawk_fedavg_straggler_fraction",
			Help: "Fraction of stragglers out of total nodes [0.0, 1.0].",
		},
		[]string{"scenario", "tier"},
	)

	// fedavgGradientsReceivedTotal counts total gradients received (before filtering).
	fedavgGradientsReceivedTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "mohawk_fedavg_gradients_received_total",
			Help: "Total gradient updates received from nodes.",
		},
		[]string{"scenario", "tier"},
	)

	// fedavgGradientsAggregatedTotal counts gradients after Byzantine filtering.
	fedavgGradientsAggregatedTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "mohawk_fedavg_gradients_aggregated_total",
			Help: "Total gradient updates aggregated (after Byzantine filtering).",
		},
		[]string{"scenario", "tier"},
	)

	// fedavgGradientThroughputPerSec tracks gradients aggregated per second.
	fedavgGradientThroughputPerSec = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "mohawk_fedavg_gradient_throughput_per_sec",
			Help: "Gradient aggregation throughput in gradients/second.",
		},
		[]string{"scenario", "tier"},
	)

	// fedavgGradientNormQuantiles tracks L2 norm quantiles (p50, p95, p99).
	fedavgGradientNormQuantiles = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "mohawk_fedavg_gradient_norm_quantile",
			Help: "L2-norm quantiles of gradient updates.",
		},
		[]string{"scenario", "tier", "quantile"}, // quantile: "p50" | "p95" | "p99"
	)

	// fedavgByzantineFilteredTotal counts gradients rejected during Byzantine filtering.
	fedavgByzantineFilteredTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "mohawk_fedavg_byzantine_filtered_total",
			Help: "Total gradient updates rejected by Byzantine filtering (Krum/MultiKrum).",
		},
		[]string{"scenario", "tier"},
	)

	// fedavgRoundLatencyQuantiles tracks round latency quantiles (p50, p95, p99).
	fedavgRoundLatencyQuantiles = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "mohawk_fedavg_round_latency_quantile_ms",
			Help: "Round execution latency quantiles in milliseconds.",
		},
		[]string{"scenario", "tier", "quantile"}, // quantile: "p50" | "p95" | "p99"
	)

	// fedavgModelAccuracy tracks validation accuracy if available.
	fedavgModelAccuracy = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "mohawk_fedavg_model_accuracy",
			Help: "Model validation accuracy (percent) [0.0, 100.0].",
		},
		[]string{"scenario", "tier", "round"},
	)

	// fedavgModelLoss tracks validation loss if available.
	fedavgModelLoss = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "mohawk_fedavg_model_loss",
			Help: "Model validation loss.",
		},
		[]string{"scenario", "tier", "round"},
	)
)

func init() {
	prometheus.MustRegister(
		tpmQuotesTotal,
		tpmVerificationsTotal,
		consensusHonestRatio,
		hierarchicalLevels,
		ipfsOperationsTotal,
		gradientCompressionRatio,
		acceleratorOpsTotal,
		acceleratorOpLatency,
		proofBatchSize,
		aggregationWorkers,
		utilityCoinMintsTotal,
		utilityCoinTransfersTotal,
		utilityCoinMintedAmountTotal,
		utilityCoinTransferredAmountTotal,
		utilityCoinTotalSupply,
		utilityCoinTxCount,
		utilityCoinBurnsTotal,
		utilityCoinBurnedAmountTotal,
		utilityCoinHoldersCount,
		proofVerificationsTotal,
		proofVerificationLatency,
		proofVerificationP99,
		formalBFTResilienceEstimate,
		formalRDPCompositionCurrent,
		formalCommunicationCostObserved,
		formalLivenessSuccessProbability,
		pqcPolicyEnabled,
		pqcPolicyModeInfo,
		pqcPolicyEpochUnix,
		thinkerClauseConfig,
		migrationRequestsTotal,
		migrationRequestLatency,
		migrationSignaturePathTotal,
		authzDenialsTotal,
		routerRequestsTotal,
		routerProvenanceRecords,
		// FedAvg scaling metrics
		fedavgRoundDurationSeconds,
		fedavgParticipationRatio,
		fedavgStragglerCount,
		fedavgStragglerFraction,
		fedavgGradientsReceivedTotal,
		fedavgGradientsAggregatedTotal,
		fedavgGradientThroughputPerSec,
		fedavgGradientNormQuantiles,
		fedavgByzantineFilteredTotal,
		fedavgRoundLatencyQuantiles,
		fedavgModelAccuracy,
		fedavgModelLoss,
	)

	utilityCoinMintsTotal.Add(0)
	utilityCoinTransfersTotal.Add(0)
	utilityCoinMintedAmountTotal.Add(0)
	utilityCoinTransferredAmountTotal.Add(0)
	utilityCoinTotalSupply.Set(0)
	utilityCoinTxCount.Set(0)
	utilityCoinBurnsTotal.Add(0)
	utilityCoinBurnedAmountTotal.Add(0)
	utilityCoinHoldersCount.Set(0)
	routerProvenanceRecords.Set(0)
}

func ObserveQuote(success bool) {
	tpmQuotesTotal.WithLabelValues(resultLabel(success)).Inc()
}

func ObserveVerification(success bool) {
	tpmVerificationsTotal.WithLabelValues(resultLabel(success)).Inc()
}

func ObserveConsensus(scope string, honestNodes int, totalNodes int) {
	if totalNodes <= 0 {
		return
	}
	consensusHonestRatio.WithLabelValues(scope).Set(float64(honestNodes) / float64(totalNodes))
}

func ObserveHVALevels(scope string, levels int) {
	hierarchicalLevels.WithLabelValues(scope).Set(float64(levels))
}

func ObserveIPFSOperation(operation string, success bool) {
	ipfsOperationsTotal.WithLabelValues(operation, resultLabel(success)).Inc()
}

// ObserveGradientCompression records the compression ratio for the given
// quantization format ("fp16" or "int8").
func ObserveGradientCompression(format string, ratio float64) {
	gradientCompressionRatio.WithLabelValues(format).Observe(ratio)
}

// ObserveAcceleratorOp increments the accelerator operation counter.
func ObserveAcceleratorOp(backend, operation string, success bool) {
	acceleratorOpsTotal.WithLabelValues(backend, operation, resultLabel(success)).Inc()
}

// ObserveAcceleratorOpLatency records accelerator operation latency in milliseconds.
func ObserveAcceleratorOpLatency(backend, operation string, latencyMS float64) {
	if latencyMS < 0 {
		return
	}
	acceleratorOpLatency.WithLabelValues(backend, operation).Observe(latencyMS)
}

// ObserveProofBatch records the size of a BatchVerifyProofs invocation.
func ObserveProofBatch(count int, success bool) {
	proofBatchSize.WithLabelValues(resultLabel(success)).Observe(float64(count))
}

// ObserveAggregationWorkers records how many parallel workers were used.
func ObserveAggregationWorkers(n int) {
	aggregationWorkers.Set(float64(n))
}

// ObserveUtilityCoinMint records a successful mint and updates supply/tx gauges.
func ObserveUtilityCoinMint(amount float64, totalSupply float64, txCount int) {
	utilityCoinMintsTotal.Inc()
	if amount > 0 {
		utilityCoinMintedAmountTotal.Add(amount)
	}
	if totalSupply >= 0 {
		utilityCoinTotalSupply.Set(totalSupply)
	}
	if txCount >= 0 {
		utilityCoinTxCount.Set(float64(txCount))
	}
}

// ObserveUtilityCoinTransfer records a successful transfer and updates tx gauge.
func ObserveUtilityCoinTransfer(amount float64, txCount int) {
	utilityCoinTransfersTotal.Inc()
	if amount > 0 {
		utilityCoinTransferredAmountTotal.Add(amount)
	}
	if txCount >= 0 {
		utilityCoinTxCount.Set(float64(txCount))
	}
}

// ObserveUtilityCoinSnapshot updates supply and tx-count gauges from a ledger snapshot.
func ObserveUtilityCoinSnapshot(totalSupply float64, txCount int) {
	if totalSupply >= 0 {
		utilityCoinTotalSupply.Set(totalSupply)
	}
	if txCount >= 0 {
		utilityCoinTxCount.Set(float64(txCount))
	}
}

// ObserveUtilityCoinBurn records a successful burn and updates supply/tx/holders gauges.
func ObserveUtilityCoinBurn(amount float64, totalSupply float64, txCount int, holders int) {
	utilityCoinBurnsTotal.Inc()
	if amount > 0 {
		utilityCoinBurnedAmountTotal.Add(amount)
	}
	if totalSupply >= 0 {
		utilityCoinTotalSupply.Set(totalSupply)
	}
	if txCount >= 0 {
		utilityCoinTxCount.Set(float64(txCount))
	}
	if holders >= 0 {
		utilityCoinHoldersCount.Set(float64(holders))
	}
}

// ObserveUtilityCoinHolders updates the unique-holder count gauge.
func ObserveUtilityCoinHolders(count int) {
	if count >= 0 {
		utilityCoinHoldersCount.Set(float64(count))
	}
}

// ObserveProofVerification records a single zk-proof verification.
// scheme: "groth16" | "fri" | "winterfell" | "hybrid"
func ObserveProofVerification(scheme string, success bool, latencyMS float64) {
	if scheme == "" {
		scheme = "groth16"
	}
	proofVerificationsTotal.WithLabelValues(scheme, resultLabel(success)).Inc()
	if latencyMS >= 0 {
		proofVerificationLatency.WithLabelValues(scheme).Observe(latencyMS)
		proofVerificationP99.WithLabelValues(scheme).Observe(latencyMS)
	}
}

// ObserveFormalBFTResilience records the current honest-node ratio estimate.
func ObserveFormalBFTResilience(scope string, ratio float64) {
	scope = sanitizeLabel(scope, "unknown")
	if ratio < 0 {
		ratio = 0
	}
	formalBFTResilienceEstimate.WithLabelValues(scope).Set(ratio)
}

// ObserveFormalRDPComposition records the current composed epsilon value.
func ObserveFormalRDPComposition(scope string, epsilon float64) {
	scope = sanitizeLabel(scope, "unknown")
	if epsilon < 0 {
		epsilon = 0
	}
	formalRDPCompositionCurrent.WithLabelValues(scope).Set(epsilon)
}

// ObserveFormalCommunicationCost records the observed communication-cost proxy.
func ObserveFormalCommunicationCost(scope string, cost float64) {
	scope = sanitizeLabel(scope, "unknown")
	if cost < 0 {
		return
	}
	formalCommunicationCostObserved.WithLabelValues(scope).Observe(cost)
}

// ObserveFormalLivenessSuccessProbability records the current liveness estimate.
func ObserveFormalLivenessSuccessProbability(scope string, probability float64) {
	scope = sanitizeLabel(scope, "unknown")
	if probability < 0 {
		probability = 0
	}
	if probability > 1 {
		probability = 1
	}
	formalLivenessSuccessProbability.WithLabelValues(scope).Set(probability)
}

// ObservePQCPolicyEnabled records whether a policy control is enforced.
func ObservePQCPolicyEnabled(policy string, enabled bool) {
	policy = sanitizeLabel(policy, "unknown")
	if enabled {
		pqcPolicyEnabled.WithLabelValues(policy).Set(1)
		return
	}
	pqcPolicyEnabled.WithLabelValues(policy).Set(0)
}

// ObservePQCPolicyMode records the active mode for a given policy control.
func ObservePQCPolicyMode(policy string, mode string) {
	policy = sanitizeLabel(policy, "unknown")
	mode = sanitizeLabel(mode, "unknown")
	pqcPolicyModeInfo.WithLabelValues(policy, mode).Set(1)
}

// ObservePQCEpochUnix records configured epoch values as unix timestamps.
func ObservePQCEpochUnix(policy string, epoch int64) {
	policy = sanitizeLabel(policy, "unknown")
	pqcPolicyEpochUnix.WithLabelValues(policy).Set(float64(epoch))
}

// ObserveThinkerClauseValue exports thinker-clause configuration values.
func ObserveThinkerClauseValue(setting string, value float64) {
	setting = sanitizeLabel(setting, "unknown")
	thinkerClauseConfig.WithLabelValues(setting).Set(value)
}

// ObserveMigrationRequest records migration endpoint request result and latency.
func ObserveMigrationRequest(endpoint string, success bool, latencyMS float64) {
	endpoint = sanitizeLabel(endpoint, "unknown")
	migrationRequestsTotal.WithLabelValues(endpoint, resultLabel(success)).Inc()
	if latencyMS >= 0 {
		migrationRequestLatency.WithLabelValues(endpoint).Observe(latencyMS)
	}
}

// ObserveMigrationSignaturePath records migration signature path outcomes.
func ObserveMigrationSignaturePath(path string, success bool) {
	path = sanitizeLabel(path, "unknown")
	migrationSignaturePathTotal.WithLabelValues(path, resultLabel(success)).Inc()
}

// ObserveAuthzDenial records authorization denials for API endpoints.
func ObserveAuthzDenial(endpoint string, reason string) {
	endpoint = sanitizeLabel(endpoint, "unknown")
	reason = sanitizeLabel(reason, "unknown")
	authzDenialsTotal.WithLabelValues(endpoint, reason).Inc()
}

// ObserveRouterRequest records router endpoint request outcomes.
func ObserveRouterRequest(endpoint string, success bool, reason string) {
	endpoint = sanitizeLabel(endpoint, "unknown")
	reason = sanitizeLabel(reason, "none")
	routerRequestsTotal.WithLabelValues(endpoint, resultLabel(success), reason).Inc()
}

// ObserveRouterProvenanceRecords updates the latest count of provenance records.
func ObserveRouterProvenanceRecords(count int) {
	if count < 0 {
		return
	}
	routerProvenanceRecords.Set(float64(count))
}

func resultLabel(success bool) string {
	if success {
		return "success"
	}
	return "failure"
}

func sanitizeLabel(value string, fallback string) string {
	v := strings.TrimSpace(strings.ToLower(value))
	if v == "" {
		return fallback
	}
	return v
}

// FedAvg Scaling Observer Functions ─────────────────────────────────────────

// ObserveFedAvgRoundDuration records the execution time of a FedAvg round.
func ObserveFedAvgRoundDuration(scenario, tier string, durationSec float64) {
	if durationSec < 0 {
		return
	}
	fedavgRoundDurationSeconds.WithLabelValues(scenario, tier).Observe(durationSec)
}

// ObserveFedAvgParticipation records the active/total node ratio.
func ObserveFedAvgParticipation(scenario, tier string, participationRatio float64) {
	fedavgParticipationRatio.WithLabelValues(scenario, tier).Set(participationRatio)
}

// ObserveFedAvgStragglers records straggler count and derived fraction.
func ObserveFedAvgStragglers(scenario, tier string, stragglerCount, totalNodes int) {
	fedavgStragglerCount.WithLabelValues(scenario, tier).Set(float64(stragglerCount))
	if totalNodes > 0 {
		fraction := float64(stragglerCount) / float64(totalNodes)
		fedavgStragglerFraction.WithLabelValues(scenario, tier).Set(fraction)
	}
}

// ObserveFedAvgGradients records received and aggregated gradient counts.
func ObserveFedAvgGradients(scenario, tier string, received, aggregated int64) {
	fedavgGradientsReceivedTotal.WithLabelValues(scenario, tier).Add(float64(received))
	fedavgGradientsAggregatedTotal.WithLabelValues(scenario, tier).Add(float64(aggregated))
}

// ObserveFedAvgGradientThroughput records gradients per second.
func ObserveFedAvgGradientThroughput(scenario, tier string, throughputPerSec float64) {
	if throughputPerSec < 0 {
		return
	}
	fedavgGradientThroughputPerSec.WithLabelValues(scenario, tier).Set(throughputPerSec)
}

// ObserveFedAvgGradientNorms records L2-norm quantiles.
func ObserveFedAvgGradientNorms(scenario, tier string, p50, p95, p99 float64) {
	fedavgGradientNormQuantiles.WithLabelValues(scenario, tier, "p50").Set(p50)
	fedavgGradientNormQuantiles.WithLabelValues(scenario, tier, "p95").Set(p95)
	fedavgGradientNormQuantiles.WithLabelValues(scenario, tier, "p99").Set(p99)
}

// ObserveFedAvgByzantineFiltered records gradients rejected by Byzantine filtering.
func ObserveFedAvgByzantineFiltered(scenario, tier string, filteredCount int64) {
	if filteredCount > 0 {
		fedavgByzantineFilteredTotal.WithLabelValues(scenario, tier).Add(float64(filteredCount))
	}
}

// ObserveFedAvgRoundLatency records round latency quantiles.
func ObserveFedAvgRoundLatency(scenario, tier string, p50Ms, p95Ms, p99Ms float64) {
	fedavgRoundLatencyQuantiles.WithLabelValues(scenario, tier, "p50").Set(p50Ms)
	fedavgRoundLatencyQuantiles.WithLabelValues(scenario, tier, "p95").Set(p95Ms)
	fedavgRoundLatencyQuantiles.WithLabelValues(scenario, tier, "p99").Set(p99Ms)
}

// ObserveFedAvgModelAccuracy records model validation accuracy (optional).
func ObserveFedAvgModelAccuracy(scenario, tier, round string, accuracyPercent float64) {
	if accuracyPercent >= 0 && accuracyPercent <= 100 {
		fedavgModelAccuracy.WithLabelValues(scenario, tier, round).Set(accuracyPercent)
	}
}

// ObserveFedAvgModelLoss records model validation loss (optional).
func ObserveFedAvgModelLoss(scenario, tier, round string, loss float64) {
	if loss >= 0 {
		fedavgModelLoss.WithLabelValues(scenario, tier, round).Set(loss)
	}
}
