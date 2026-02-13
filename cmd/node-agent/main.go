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
	"encoding/json"
	"io"
	"log"
	"net/http"
	"time"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/manifest"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/tpm"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/wasmhost"
)

func main() {
	log.Println("Node Agent starting...")
	// Satisfy tpm import
	_ = tpm.Verify("node-init", []byte{})
	// Satisfy context and wasmhost imports
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	runner := wasmhost.NewRunner()
	_ = runner
	_ = ctx
	client := &http.Client{Timeout: 10 * time.Second}
	runLoop(client)
}

func runLoop(client *http.Client) {
	for {
		data, err := fetchJob(client)
		if err != nil {
			time.Sleep(5 * time.Second)
			continue
		}
		var m manifest.Manifest
		if err := json.NewDecoder(bytes.NewReader(data)).Decode(&m); err == nil {
			log.Printf("Received task: %s", m.TaskID)
		}
		time.Sleep(10 * time.Second)
	}
}

func fetchJob(client *http.Client) ([]byte, error) {
	resp, err := client.Get("http://localhost:8080/jobs/next?node_id=node-1")
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	return io.ReadAll(resp.Body)
}
