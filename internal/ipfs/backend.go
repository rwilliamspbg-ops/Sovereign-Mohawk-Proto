package ipfs

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"net/url"
	"path"
	"strings"
	"time"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/metrics"
)

type Backend struct {
	endpoint string
	client   *http.Client
}

type AddResponse struct {
	Name string `json:"Name"`
	Hash string `json:"Hash"`
	Size string `json:"Size"`
}

func NewBackend(endpoint string) *Backend {
	clean := strings.TrimRight(endpoint, "/")
	return &Backend{
		endpoint: clean,
		client: &http.Client{
			Timeout: 15 * time.Second,
		},
	}
}

func (b *Backend) Enabled() bool {
	return b != nil && b.endpoint != ""
}

func (b *Backend) PutCheckpoint(ctx context.Context, name string, payload []byte) (string, error) {
	if !b.Enabled() {
		return "", fmt.Errorf("ipfs backend is not configured")
	}

	var body bytes.Buffer
	writer := multipart.NewWriter(&body)
	part, err := writer.CreateFormFile("file", path.Base(name))
	if err != nil {
		return "", err
	}
	if _, err := part.Write(payload); err != nil {
		return "", err
	}
	if err := writer.Close(); err != nil {
		return "", err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, b.endpoint+"/api/v0/add?pin=true", &body)
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", writer.FormDataContentType())

	resp, err := b.client.Do(req)
	if err != nil {
		metrics.ObserveIPFSOperation("put", false)
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= http.StatusBadRequest {
		metrics.ObserveIPFSOperation("put", false)
		bodyBytes, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("ipfs add failed: %s", strings.TrimSpace(string(bodyBytes)))
	}

	var addResp AddResponse
	if err := json.NewDecoder(resp.Body).Decode(&addResp); err != nil {
		metrics.ObserveIPFSOperation("put", false)
		return "", err
	}

	metrics.ObserveIPFSOperation("put", true)
	return addResp.Hash, nil
}

func (b *Backend) GetCheckpoint(ctx context.Context, cid string) ([]byte, error) {
	if !b.Enabled() {
		return nil, fmt.Errorf("ipfs backend is not configured")
	}

	arg := url.QueryEscape(cid)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, b.endpoint+"/api/v0/cat?arg="+arg, nil)
	if err != nil {
		return nil, err
	}

	resp, err := b.client.Do(req)
	if err != nil {
		metrics.ObserveIPFSOperation("get", false)
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= http.StatusBadRequest {
		metrics.ObserveIPFSOperation("get", false)
		bodyBytes, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("ipfs cat failed: %s", strings.TrimSpace(string(bodyBytes)))
	}

	payload, err := io.ReadAll(resp.Body)
	if err != nil {
		metrics.ObserveIPFSOperation("get", false)
		return nil, err
	}

	metrics.ObserveIPFSOperation("get", true)
	return payload, nil
}
