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
	"log"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/tpm"
)

// AttestationJob represents a verification task for a node
type AttestationJob struct {
	NodeID string
	Quote  []byte
	Resp   chan error
}

// Global job queue with a high-scale buffer
var JobQueue = make(chan AttestationJob, 10000)

// StartAttestationWorkers initializes a fixed-size pool to prevent thread exhaustion
func StartAttestationWorkers(workerCount int) {
	log.Printf("Starting %d Async Attestation Workers...", workerCount)
	for i := 0; i < workerCount; i++ {
		go func(workerID int) {
			for job := range JobQueue {
				// Offload to the internal/tpm package for hardware verification
				err := tpm.Verify(job.NodeID, job.Quote)
				job.Resp <- err
			}
		}(i)
	}
}
