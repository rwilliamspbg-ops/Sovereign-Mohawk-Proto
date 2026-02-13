/*
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package main

import (
	"net/http"
	"time"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/tpm"
)

// AttestationJob encapsulates the data for a non-blocking worker pool
type AttestationJob struct {
	NodeID string
	Quote  []byte
	Resp   chan error
}

// JobQueue defines the buffer for the worker pool (10,000 capacity)
var JobQueue = make(chan AttestationJob, 10000)

type Server struct{}

// StartAttestationWorkers initializes a pool of goroutines to process jobs asynchronously
func StartAttestationWorkers(count int) {
	for i := 0; i < count; i++ {
		go func() {
			for job := range JobQueue {
				// Verify the quote against cache or hardware without blocking the main thread
				err := tpm.Verify(job.NodeID, job.Quote)
				job.Resp <- err
			}
		}()
	}
}

// HandleAttest serves as the primary endpoint for node attestation
func (s *Server) HandleAttest(w http.ResponseWriter, r *http.Request) {
	// 1. Quick validation of header metadata
	nodeID := r.Header.Get("X-Node-ID")

	// 2. Offload the heavy lifting to the worker pool
	respChan := make(chan error)
	JobQueue <- AttestationJob{
		NodeID: nodeID, 
		Resp:   respChan,
	}

	// 3. Set a timeout to ensure system liveness and prevent hangs
	select {
	case err := <-respChan:
		if err != nil {
			http.Error(w, "Attestation Forbidden", 403)
			return
		}
		w.WriteHeader(200)
	case <-time.After(2 * time.Second):
		w.WriteHeader(504) // Gateway Timeout if hardware is unresponsive
	}
}
