// cmd/node-agent/main.go
package main

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"os"
	"time"

	"sovereign/internal/manifest"
	"sovereign/internal/tpm"
	"sovereign/internal/wasmhost"
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
	if resp.StatusCode != 200 {
		return nil, io.ErrUnexpectedEOF
	}
	var nj NextJobResponse
	if err := json.NewDecoder(resp.Body).Decode(&nj); err != nil {
		return nil, err
	}
	return &nj, nil
}

func sendGradients(payload []byte) error {
	req, _ := http.NewRequest("POST", "http://fl-aggregator:8090/fl/submit", nil)
	req.Body = io.NopCloser(
		io.Reader(
			os.NewFile(uintptr(0), ""),
		),
	)
	// for prototype, just log payload length; wire real JSON here.
	log.Printf("would send %d bytes to FL aggregator", len(payload))
	return nil
}

func hashMatches(b []byte, hexSha string) bool {
	sum := sha256.Sum256(b)
	return hex.EncodeToString(sum[:]) == hexSha
}

