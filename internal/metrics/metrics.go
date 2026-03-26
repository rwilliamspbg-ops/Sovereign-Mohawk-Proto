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

	// bridgeSettlementsTotal counts bridge settlement attempts by asset and outcome.
	bridgeSettlementsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "mohawk_bridge_settlements_total",
			Help: "Total bridge settlement operations by asset and status.",
		},
		[]string{"asset", "status"}, // status: settled | refunded | failed
	)

	// bridgeSettlementVolumeTotal accumulates the gross settlement volume per asset.
	bridgeSettlementVolumeTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "mohawk_bridge_settlement_volume_total",
			Help: "Cumulative settlement volume per asset.",
		},
		[]string{"asset"},
	)

	// bridgeTransfersTotal counts bridge transfer verifications by source/target chain pair.
	bridgeTransfersTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "mohawk_bridge_transfers_total",
			Help: "Total verified bridge transfers per chain pair.",
		},
		[]string{"source_chain", "target_chain", "result"},
	)

	// bridgeTransferLatency records bridge transfer processing latency in milliseconds.
	bridgeTransferLatency = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "mohawk_bridge_transfer_latency_ms",
			Help:    "Bridge transfer verification/settlement latency in milliseconds.",
			Buckets: []float64{0.1, 0.5, 1, 2, 5, 10, 25, 50, 100, 250, 500},
		},
		[]string{"source_chain", "target_chain", "result"},
	)

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
		bridgeSettlementsTotal,
		bridgeSettlementVolumeTotal,
		bridgeTransfersTotal,
		bridgeTransferLatency,
		proofVerificationsTotal,
		proofVerificationLatency,
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

// ObserveBridgeSettlement records a bridge settlement outcome.
// status must be "settled", "refunded", or "failed".
func ObserveBridgeSettlement(asset string, status string, amount float64) {
	asset = strings.ToUpper(strings.TrimSpace(asset))
	if asset == "" {
		asset = "UNKNOWN"
	}
	bridgeSettlementsTotal.WithLabelValues(asset, status).Inc()
	if amount > 0 {
		bridgeSettlementVolumeTotal.WithLabelValues(asset).Add(amount)
	}
}

// ObserveBridgeTransfer records a bridge transfer verification.
func ObserveBridgeTransfer(sourceChain, targetChain string, success bool) {
	source := strings.ToLower(strings.TrimSpace(sourceChain))
	target := strings.ToLower(strings.TrimSpace(targetChain))
	bridgeTransfersTotal.WithLabelValues(source, target, resultLabel(success)).Inc()
}

// ObserveBridgeTransferLatency records bridge transfer latency in milliseconds.
func ObserveBridgeTransferLatency(sourceChain, targetChain string, success bool, latencyMS float64) {
	if latencyMS < 0 {
		return
	}
	source := strings.ToLower(strings.TrimSpace(sourceChain))
	target := strings.ToLower(strings.TrimSpace(targetChain))
	bridgeTransferLatency.WithLabelValues(source, target, resultLabel(success)).Observe(latencyMS)
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
	}
}

func resultLabel(success bool) string {
	if success {
		return "success"
	}
	return "failure"
}
