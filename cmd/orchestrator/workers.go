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
	// Ensure this path matches the module name in your go.mod
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/tpm"
)

// StartAttestationWorkers initializes a pool of goroutines to process jobs.
// Note: JobQueue must be defined in another file within 'package main' (e.g., server.go)
func StartAttestationWorkers(count int) {
	log.Printf("Starting %d Async Attestation Workers...", count)
	for i := 0; i < count; i++ {
		go func() {
			// The linter error 'undefined: JobQueue' occurs if server.go 
			// (where JobQueue is defined) isn't included in the linting run.
			for job := range JobQueue {
				// verify the hardware quote
				err := tpm.Verify(job.NodeID, job.Quote)
				job.Resp <- err
			}
		}()
	}
}
