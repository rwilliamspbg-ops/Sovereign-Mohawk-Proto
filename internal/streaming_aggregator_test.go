// Copyright 2026 Sovereign-Mohawk Core Team
// Licensed under the Apache License, Version 2.0
// Unit tests for streaming aggregator

package internal

import (
	"testing"
	"time"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/transport"
)

// TestStreamingAggregatorChunkReassembly verifies tensor reconstruction from chunks
func TestStreamingAggregatorChunkReassembly(t *testing.T) {
	mrc := transport.NewMRCAdapter("test-node", 4)
	opts := StreamingAggregatorOptions{
		MaxBufferedTensors: 100,
		TensorTimeoutSec:   10.0,
		CheckpointInterval: 100 * time.Millisecond,
		EnableByzantine:    false,
	}
	agg := NewStreamingAggregator(Regional, mrc, opts)

	// Create 5 chunks of a 500-element tensor
	chunkSize := 100
	tensorID := "test-tensor-1"

	for i := 0; i < 5; i++ {
		payload := make([]float32, chunkSize)
		for j := range payload {
			payload[j] = float32(i*chunkSize + j)
		}

		chunk := transport.GradientChunk{
			ID:       tensorID,
			NodeID:   "node-1",
			Index:    i,
			Total:    5,
			Payload:  payload,
			SentTime: time.Now().UnixNano(),
		}

		if err := agg.IngestChunk(chunk); err != nil {
			t.Fatalf("IngestChunk failed: %v", err)
		}
	}

	// Verify reassembly
	stats := agg.GetStats()
	if stats["total_chunks_ingested"] != int64(5) {
		t.Fatalf("expected 5 chunks ingested, got %d", stats["total_chunks_ingested"])
	}
	if stats["total_tensors_ready"] != int64(1) {
		t.Fatalf("expected 1 tensor ready, got %d", stats["total_tensors_ready"])
	}

	t.Logf("✓ Chunk reassembly test passed (5 chunks -> 1 tensor)")
}

// TestStreamingAggregatorOutOfOrderChunks verifies out-of-order assembly
func TestStreamingAggregatorOutOfOrderChunks(t *testing.T) {
	mrc := transport.NewMRCAdapter("test-node", 4)
	opts := StreamingAggregatorOptions{
		MaxBufferedTensors: 100,
		TensorTimeoutSec:   10.0,
		CheckpointInterval: 100 * time.Millisecond,
		EnableByzantine:    false,
	}
	agg := NewStreamingAggregator(Regional, mrc, opts)

	tensorID := "test-out-of-order"
	chunkOrder := []int{2, 0, 4, 1, 3} // Scrambled order

	for _, idx := range chunkOrder {
		payload := make([]float32, 50)
		for j := range payload {
			payload[j] = float32(idx*50 + j)
		}

		chunk := transport.GradientChunk{
			ID:       tensorID,
			NodeID:   "node-2",
			Index:    idx,
			Total:    5,
			Payload:  payload,
			SentTime: time.Now().UnixNano(),
		}

		if err := agg.IngestChunk(chunk); err != nil {
			t.Fatalf("IngestChunk failed at index %d: %v", idx, err)
		}
	}

	stats := agg.GetStats()
	if stats["total_tensors_ready"] != int64(1) {
		t.Fatalf("expected 1 tensor ready (despite out-of-order), got %d", stats["total_tensors_ready"])
	}

	t.Logf("✓ Out-of-order chunk reassembly test passed (5 chunks in scrambled order)")
}

// TestStreamingAggregatorMultipleTensors verifies concurrent tensor buffering
func TestStreamingAggregatorMultipleTensors(t *testing.T) {
	mrc := transport.NewMRCAdapter("test-node", 4)
	opts := StreamingAggregatorOptions{
		MaxBufferedTensors: 100,
		TensorTimeoutSec:   10.0,
		CheckpointInterval: 100 * time.Millisecond,
		EnableByzantine:    false,
	}
	agg := NewStreamingAggregator(Regional, mrc, opts)

	// Send interleaved chunks for 3 different tensors
	for tensorNum := 0; tensorNum < 3; tensorNum++ {
		tensorID := "tensor-" + string(rune(tensorNum))
		for chunkIdx := 0; chunkIdx < 4; chunkIdx++ {
			payload := make([]float32, 25)
			chunk := transport.GradientChunk{
				ID:       tensorID,
				NodeID:   "node-3",
				Index:    chunkIdx,
				Total:    4,
				Payload:  payload,
				SentTime: time.Now().UnixNano(),
			}

			if err := agg.IngestChunk(chunk); err != nil {
				t.Fatalf("IngestChunk failed: %v", err)
			}
		}
	}

	stats := agg.GetStats()
	if stats["total_tensors_ready"] != int64(3) {
		t.Fatalf("expected 3 tensors ready, got %d", stats["total_tensors_ready"])
	}

	t.Logf("✓ Multiple tensor buffering test passed (3 concurrent tensors)")
}

// TestStreamingAggregatorTimeout verifies stale buffer eviction
func TestStreamingAggregatorTimeout(t *testing.T) {
	mrc := transport.NewMRCAdapter("test-node", 4)
	opts := StreamingAggregatorOptions{
		MaxBufferedTensors: 100,
		TensorTimeoutSec:   0.1, // 100ms timeout for testing
		CheckpointInterval: 50 * time.Millisecond,
		EnableByzantine:    false,
	}
	agg := NewStreamingAggregator(Regional, mrc, opts)

	// Send only 2 of 5 chunks (incomplete)
	tensorID := "incomplete-tensor"
	for i := 0; i < 2; i++ {
		payload := make([]float32, 100)
		chunk := transport.GradientChunk{
			ID:       tensorID,
			NodeID:   "node-4",
			Index:    i,
			Total:    5,
			Payload:  payload,
			SentTime: time.Now().UnixNano(),
		}

		if err := agg.IngestChunk(chunk); err != nil {
			t.Fatalf("IngestChunk failed: %v", err)
		}
	}

	// Manually trigger checkpoint
	time.Sleep(150 * time.Millisecond)
	agg.checkpointStaleBuffers()

	stats := agg.GetStats()
	bufferedCount, ok := stats["buffered_tensors"].(int)
	if !ok {
		t.Fatalf("buffered_tensors is not int: %T", stats["buffered_tensors"])
	}
	if bufferedCount != 0 {
		t.Fatalf("expected stale buffer evicted, got %d buffered", bufferedCount)
	}

	t.Logf("✓ Stale buffer timeout test passed (incomplete tensor evicted)")
}

// TestStreamingAggregatorBufferOverflow verifies backpressure handling
func TestStreamingAggregatorBufferOverflow(t *testing.T) {
	mrc := transport.NewMRCAdapter("test-node", 4)
	opts := StreamingAggregatorOptions{
		MaxBufferedTensors: 2, // Very small for testing
		TensorTimeoutSec:   10.0,
		CheckpointInterval: 100 * time.Millisecond,
		EnableByzantine:    false,
	}
	agg := NewStreamingAggregator(Regional, mrc, opts)

	// Fill buffer
	for tensorNum := 0; tensorNum < 2; tensorNum++ {
		tensorID := "tensor-full-" + string(rune(tensorNum))
		for chunkIdx := 0; chunkIdx < 3; chunkIdx++ {
			payload := make([]float32, 10)
			chunk := transport.GradientChunk{
				ID:       tensorID,
				NodeID:   "node-5",
				Index:    chunkIdx,
				Total:    4,
				Payload:  payload,
				SentTime: time.Now().UnixNano(),
			}

			if err := agg.IngestChunk(chunk); err != nil {
				t.Fatalf("IngestChunk failed: %v", err)
			}
		}
	}

	// Try to exceed buffer
	tensorID := "overflow-tensor"
	chunk := transport.GradientChunk{
		ID:       tensorID,
		NodeID:   "node-6",
		Index:    0,
		Total:    4,
		Payload:  make([]float32, 10),
		SentTime: time.Now().UnixNano(),
	}

	err := agg.IngestChunk(chunk)
	if err == nil {
		t.Fatalf("expected buffer overflow error, got nil")
	}

	t.Logf("✓ Buffer overflow test passed (rejected when full)")
}

// BenchmarkStreamingAggregatorIngest measures chunk ingestion throughput
func BenchmarkStreamingAggregatorIngest(b *testing.B) {
	mrc := transport.NewMRCAdapter("bench-node", 4)
	opts := StreamingAggregatorOptions{
		MaxBufferedTensors: 1000,
		TensorTimeoutSec:   60.0,
		CheckpointInterval: 500 * time.Millisecond,
		EnableByzantine:    false,
	}
	agg := NewStreamingAggregator(Regional, mrc, opts)

	payload := make([]float32, 1000)
	for i := range payload {
		payload[i] = float32(i)
	}

	b.ReportAllocs()
	b.ResetTimer()

	for i := 0; i < b.N; i++ {
		chunk := transport.GradientChunk{
			ID:       "bench-tensor",
			NodeID:   "bench-node",
			Index:    (i % 10),
			Total:    10,
			Payload:  payload,
			SentTime: time.Now().UnixNano(),
		}

		if err := agg.IngestChunk(chunk); err != nil {
			b.Fatalf("IngestChunk error: %v", err)
		}

		// Prevent buffer overflow in benchmark
		if (i % 1000) == 0 {
			agg.mu.Lock()
			agg.chunkBuffers = make(map[string]*ChunkAssembly)
			agg.mu.Unlock()
		}
	}

	b.StopTimer()
	opsPerSec := float64(b.N) / b.Elapsed().Seconds()
	b.Logf("Throughput: %.0f chunks/sec", opsPerSec)
}
