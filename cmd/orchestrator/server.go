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
)

type Server struct{}

// HandleAttest offloads hardware calls to the worker pool
func (s *Server) HandleAttest(w http.ResponseWriter, r *http.Request) {
	nodeID := r.Header.Get("X-Node-ID")
	quote := []byte("attestation_payload") // Simulated

	respChan := make(chan error, 1)
	
	// Delegate job to workers
	JobQueue <- AttestationJob{
		NodeID: nodeID,
		Quote:  quote,
		Resp:   respChan,
	}

	// Wait with a timeout to maintain system liveness
	select {
	case err := <-respChan:
		if err != nil {
			http.Error(w, "Attestation Failed", http.StatusForbidden)
			return
		}
		w.WriteHeader(http.StatusOK)
	case <-time.After(2 * time.Second):
		http.Error(w, "Hardware Response Timeout", http.StatusGatewayTimeout)
	}
}
