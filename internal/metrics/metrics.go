package metrics

import "github.com/prometheus/client_golang/prometheus"

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
		proofBatchSize,
		aggregationWorkers,
		utilityCoinMintsTotal,
		utilityCoinTransfersTotal,
		utilityCoinMintedAmountTotal,
		utilityCoinTransferredAmountTotal,
		utilityCoinTotalSupply,
		utilityCoinTxCount,
	)

	utilityCoinMintsTotal.Add(0)
	utilityCoinTransfersTotal.Add(0)
	utilityCoinMintedAmountTotal.Add(0)
	utilityCoinTransferredAmountTotal.Add(0)
	utilityCoinTotalSupply.Set(0)
	utilityCoinTxCount.Set(0)
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

func resultLabel(success bool) string {
	if success {
		return "success"
	}
	return "failure"
}
