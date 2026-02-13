// Copyright 2026 Sovereign-Mohawk Core Team
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"time"

	"github.com/your-org/sovereign-mohawk-proto/internal/manifest"
	"github.com/your-org/sovereign-mohawk-proto/internal/tpm"
	"github.com/your-org/sovereign-mohawk-proto/internal/wasmhost"
)

var nodeID = "node-1"

type NextJobResponse struct {
	Wasm []byte            `json:"wasm"`
	Man  manifest.Manifest `json:"manifest"`
}

func main() {
	orchPub := fetchOrchestratorPub()
	runner := wasmhost.NewRunner()

	for {
		job, err := fetchJob()
		if err != nil {
			log.Println("no job:", err)
			time.Sleep(3 * time.Second)
			continue
		}

		if err := tpm.VerifyNodeState(); err != nil {
			log.Println("TPM verify failed:", err)
			continue
		}

		if err := manifest.VerifySignature(&job.Man, orchPub); err != nil {
			log.Println("manifest invalid:", err)
			continue
		}

		if !hashMatches(job.Wasm, job.Man.WasmModuleSHA256) {
			log.Println("wasm hash mismatch")
			continue
		}

		env := &wasmhost.HostEnv{
			Caps: map[manifest.Capability]bool{},
			LogFn: func(level, msg string) {
				log.Printf("[%s] %s", level, msg)
			},
			FLSend: func(payload []byte) error {
				return sendGradients(payload)
			},
		}
		for _, c := range job.Man.Capabilities {
			env.Caps[c] = true
		}

		log.Println("running task", job.Man.TaskID)
		ctx := context.Background()
		if err := runner.RunTask(ctx, job.Wasm, &job.Man, env); err != nil {
			log.Println("task error:", err)
		}
	}
}

func fetchOrchestratorPub() []byte {
	resp, err := http.Get("http://orchestrator:8080/orchestrator/pubkey")
	if err != nil {
		log.Fatal(err)
	}
	defer resp.Body.Close()
	hexKey, _ := io.ReadAll(resp.Body)
	pub, _ := hex.DecodeString(string(hexKey))
	return pub
}

func fetchJob() (*NextJobResponse, error) {
	url := "http://orchestrator:8080/jobs/next?node_id=" + nodeID
	resp, err := http.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, io.ErrUnexpectedEOF
	}
	var nj NextJobResponse
	if err := json.NewDecoder(resp.Body).Decode(&nj); err != nil {
		return nil, err
	}
	return &nj, nil
}

func sendGradients(payload []byte) error {
	reqBody := map[string]interface{}{
		"node_id": nodeID,
		"grads":   []float64{1.0, 2.0, 3.0}, // demo payload
	}
	b, _ := json.Marshal(reqBody)

	resp, err := http.Post("http://fl-aggregator:8090/fl/submit", "application/json", bytes.NewReader(b))
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	log.Printf("sent gradients, status %s", resp.Status)
	return nil
}

func hashMatches(b []byte, hexSha string) bool {
	sum := sha256.Sum256(b)
	return hex.EncodeToString(sum[:]) == hexSha
}
