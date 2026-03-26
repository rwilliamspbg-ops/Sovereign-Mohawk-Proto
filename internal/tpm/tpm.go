package tpm

import (
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/binary"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"math/big"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/hva"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/metrics"
)

type CachedQuote struct {
	Quote     []byte
	ExpiresAt time.Time
}

type QuoteEnvelope struct {
	NodeID         string    `json:"node_id"`
	PCRDigest      []byte    `json:"pcr_digest"`
	IssuedAt       time.Time `json:"issued_at"`
	ExpiresAt      time.Time `json:"expires_at"`
	SignatureAlgo  string    `json:"signature_algo,omitempty"`
	SignatureIndex uint64    `json:"signature_index,omitempty"`
	HashSigPublic  []byte    `json:"hash_sig_public,omitempty"`
	Signature      []byte    `json:"signature"`
	CertificatePEM []byte    `json:"certificate_pem"`
}

type AttestationSignatureMode string

const (
	AttestationSignatureRSA  AttestationSignatureMode = "rsa-pss-sha256"
	AttestationSignatureXMSS AttestationSignatureMode = "xmss"
)

func ParseAttestationSignatureMode(raw string) AttestationSignatureMode {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "", "default", "pqc", string(AttestationSignatureXMSS), "lms", "xmss-lms":
		return AttestationSignatureXMSS
	case string(AttestationSignatureRSA), "rsa", "rsa-pss":
		return AttestationSignatureRSA
	default:
		return AttestationSignatureMode("")
	}
}

func ActiveAttestationSignatureMode() AttestationSignatureMode {
	return ParseAttestationSignatureMode(os.Getenv("MOHAWK_TPM_IDENTITY_SIG_MODE"))
}

type Authority struct {
	cert *x509.Certificate
	key  *rsa.PrivateKey
}

type Attestor struct {
	nodeID    string
	authority *Authority
	tlsCert   tls.Certificate
	leafCert  *x509.Certificate
	key       *rsa.PrivateKey
	pcrDigest []byte
	sigMode   AttestationSignatureMode
	hashSeed  [32]byte
	sigIndex  uint64
	sigMu     sync.Mutex
}

var (
	quoteCache        = make(map[string]CachedQuote)
	cacheMutex        sync.RWMutex
	defaultAuthority  *Authority
	defaultAuthorityE error
	authorityMutex    sync.Mutex
	attestors         = map[string]*Attestor{}
	attestorMutex     sync.Mutex
	xmssSeenIndex     = map[string]uint64{}
	xmssSeenMutex     sync.Mutex
)

const (
	defaultAuthorityTTL          = 24 * time.Hour
	defaultAuthorityRotateBefore = 30 * time.Minute
)

func GetVerifiedQuote(nodeID string) ([]byte, error) {
	mode := ActiveAttestationSignatureMode()
	if mode != AttestationSignatureXMSS {
		cacheMutex.RLock()
		entry, found := quoteCache[nodeID]
		cacheMutex.RUnlock()

		if found && time.Now().Before(entry.ExpiresAt) {
			return entry.Quote, nil
		}
	}

	attestor, err := getAttestor(nodeID)
	if err != nil {
		metrics.ObserveQuote(false)
		return nil, err
	}

	quote, err := attestor.GenerateQuote()
	if err != nil {
		metrics.ObserveQuote(false)
		return nil, err
	}

	if mode != AttestationSignatureXMSS {
		cacheMutex.Lock()
		quoteCache[nodeID] = CachedQuote{
			Quote:     quote,
			ExpiresAt: time.Now().Add(5 * time.Minute),
		}
		cacheMutex.Unlock()
	}
	metrics.ObserveQuote(true)
	return quote, nil
}

func Verify(nodeID string, quote []byte) error {
	var envelope QuoteEnvelope
	if err := json.Unmarshal(quote, &envelope); err != nil {
		metrics.ObserveVerification(false)
		return fmt.Errorf("invalid attestation payload: %w", err)
	}
	if envelope.NodeID != nodeID {
		metrics.ObserveVerification(false)
		return fmt.Errorf("node mismatch: expected %s, got %s", nodeID, envelope.NodeID)
	}
	if time.Now().After(envelope.ExpiresAt) {
		metrics.ObserveVerification(false)
		return fmt.Errorf("attestation for %s expired", nodeID)
	}

	cert, err := parseCertificate(envelope.CertificatePEM)
	if err != nil {
		metrics.ObserveVerification(false)
		return err
	}

	pool := x509.NewCertPool()
	authority, err := getAuthority()
	if err != nil {
		metrics.ObserveVerification(false)
		return err
	}
	pool.AddCert(authority.cert)

	if _, err := cert.Verify(x509.VerifyOptions{Roots: pool, CurrentTime: time.Now()}); err != nil {
		metrics.ObserveVerification(false)
		return fmt.Errorf("certificate validation failed: %w", err)
	}

	payload, err := envelope.payloadDigest()
	if err != nil {
		metrics.ObserveVerification(false)
		return err
	}
	mode := ParseAttestationSignatureMode(envelope.SignatureAlgo)
	if envelope.SignatureAlgo == "" {
		mode = AttestationSignatureRSA
	}
	switch mode {
	case AttestationSignatureRSA:
		pub, ok := cert.PublicKey.(*rsa.PublicKey)
		if !ok {
			metrics.ObserveVerification(false)
			return fmt.Errorf("attestor certificate is not RSA")
		}
		if err := rsa.VerifyPSS(pub, crypto.SHA256, payload, envelope.Signature, nil); err != nil {
			metrics.ObserveVerification(false)
			return fmt.Errorf("rsa-pss verification failed: %w", err)
		}
	case AttestationSignatureXMSS:
		if len(envelope.HashSigPublic) == 0 {
			metrics.ObserveVerification(false)
			return fmt.Errorf("xmss verification failed: missing hash_sig_public")
		}
		if err := verifyStatefulHashSignature(payload, envelope.Signature, envelope.HashSigPublic); err != nil {
			metrics.ObserveVerification(false)
			return fmt.Errorf("xmss verification failed: %w", err)
		}
		xmssSeenMutex.Lock()
		if last, ok := xmssSeenIndex[nodeID]; ok && envelope.SignatureIndex <= last {
			xmssSeenMutex.Unlock()
			metrics.ObserveVerification(false)
			return fmt.Errorf("xmss verification failed: replay index %d <= %d", envelope.SignatureIndex, last)
		}
		xmssSeenIndex[nodeID] = envelope.SignatureIndex
		xmssSeenMutex.Unlock()
	default:
		metrics.ObserveVerification(false)
		return fmt.Errorf("unsupported signature mode %q", envelope.SignatureAlgo)
	}

	metrics.ObserveVerification(true)
	return nil
}

func GenerateTPMQuote() ([]byte, error) {
	return GetVerifiedQuote("default-node")
}

func VerifyByzantineResilience(totalNodes int, maliciousNodes int) (bool, error) {
	if totalNodes <= 0 {
		return false, fmt.Errorf("total nodes must be positive")
	}
	if maliciousNodes < 0 || maliciousNodes > totalNodes {
		return false, fmt.Errorf("malicious node count out of range")
	}

	maxByzantine := hva.MaximumByzantineNodes(totalNodes)
	if maliciousNodes > maxByzantine {
		return false, fmt.Errorf(
			"security threshold violated: Theorem 1 allows at most %d Byzantine nodes out of %d at the 55.5%% honest boundary",
			maxByzantine,
			totalNodes,
		)
	}
	return true, nil
}

func CalculateGlobalTolerance(fTiers []int) int {
	total := 0
	for _, f := range fTiers {
		total += f
	}
	return total
}

func ServerTLSConfig(nodeID string) (*tls.Config, error) {
	attestor, err := getAttestor(nodeID)
	if err != nil {
		return nil, err
	}
	authority, err := getAuthority()
	if err != nil {
		return nil, err
	}
	pool := x509.NewCertPool()
	pool.AddCert(authority.cert)
	return &tls.Config{
		MinVersion:   tls.VersionTLS13,
		ClientAuth:   tls.RequireAndVerifyClientCert,
		ClientCAs:    pool,
		Certificates: []tls.Certificate{attestor.tlsCert},
	}, nil
}

func ClientTLSConfig(nodeID string, serverName string) (*tls.Config, error) {
	attestor, err := getAttestor(nodeID)
	if err != nil {
		return nil, err
	}
	authority, err := getAuthority()
	if err != nil {
		return nil, err
	}
	pool := x509.NewCertPool()
	pool.AddCert(authority.cert)
	return &tls.Config{
		MinVersion:   tls.VersionTLS13,
		RootCAs:      pool,
		ServerName:   serverName,
		Certificates: []tls.Certificate{attestor.tlsCert},
	}, nil
}

func getAttestor(nodeID string) (*Attestor, error) {
	attestorMutex.Lock()
	defer attestorMutex.Unlock()

	authority, err := getAuthority()
	if err != nil {
		return nil, err
	}
	if attestor, ok := attestors[nodeID]; ok && attestor.authority == authority {
		return attestor, nil
	}
	attestor, err := newAttestor(nodeID, authority)
	if err != nil {
		return nil, err
	}
	attestors[nodeID] = attestor
	return attestor, nil
}

func getAuthority() (*Authority, error) {
	authorityMutex.Lock()
	defer authorityMutex.Unlock()

	externalCertPath := strings.TrimSpace(os.Getenv("MOHAWK_TPM_CA_CERT_FILE"))
	externalKeyPath := strings.TrimSpace(os.Getenv("MOHAWK_TPM_CA_KEY_FILE"))
	if externalCertPath != "" && externalKeyPath != "" {
		authority, err := loadAuthorityFromFiles(externalCertPath, externalKeyPath)
		if err != nil {
			return nil, err
		}
		if defaultAuthority == nil || defaultAuthority.cert == nil || !defaultAuthority.cert.Equal(authority.cert) {
			defaultAuthority = authority
			defaultAuthorityE = nil
			cacheMutex.Lock()
			quoteCache = make(map[string]CachedQuote)
			cacheMutex.Unlock()
		}
		return defaultAuthority, nil
	}

	if defaultAuthority != nil && defaultAuthorityE == nil && !authorityNeedsRotation(defaultAuthority.cert) {
		return defaultAuthority, nil
	}
	defaultAuthority, defaultAuthorityE = newAuthority("Sovereign-Mohawk TPM Root")
	if defaultAuthorityE == nil {
		cacheMutex.Lock()
		quoteCache = make(map[string]CachedQuote)
		cacheMutex.Unlock()
	}
	return defaultAuthority, defaultAuthorityE
}

func loadAuthorityFromFiles(certPath string, keyPath string) (*Authority, error) {
	certPEM, err := os.ReadFile(certPath)
	if err != nil {
		return nil, fmt.Errorf("read tpm ca cert %q: %w", certPath, err)
	}
	keyPEM, err := os.ReadFile(keyPath)
	if err != nil {
		return nil, fmt.Errorf("read tpm ca key %q: %w", keyPath, err)
	}

	certBlock, _ := pem.Decode(certPEM)
	if certBlock == nil {
		return nil, fmt.Errorf("decode tpm ca cert pem %q", certPath)
	}
	cert, err := x509.ParseCertificate(certBlock.Bytes)
	if err != nil {
		return nil, fmt.Errorf("parse tpm ca cert %q: %w", certPath, err)
	}

	keyBlock, _ := pem.Decode(keyPEM)
	if keyBlock == nil {
		return nil, fmt.Errorf("decode tpm ca key pem %q", keyPath)
	}
	parsedKey, err := x509.ParsePKCS1PrivateKey(keyBlock.Bytes)
	if err != nil {
		parsedAny, errAny := x509.ParsePKCS8PrivateKey(keyBlock.Bytes)
		if errAny != nil {
			return nil, fmt.Errorf("parse tpm ca key %q: %v / %v", keyPath, err, errAny)
		}
		rsaKey, ok := parsedAny.(*rsa.PrivateKey)
		if !ok {
			return nil, fmt.Errorf("tpm ca key %q is not RSA", keyPath)
		}
		parsedKey = rsaKey
	}

	if !cert.IsCA {
		return nil, fmt.Errorf("tpm ca cert %q is not a CA certificate", certPath)
	}

	return &Authority{cert: cert, key: parsedKey}, nil
}

func authorityNeedsRotation(cert *x509.Certificate) bool {
	if cert == nil {
		return true
	}
	return time.Now().After(cert.NotAfter.Add(-rotateBeforeDuration()))
}

func authorityTTL() time.Duration {
	raw := strings.TrimSpace(os.Getenv("MOHAWK_TPM_CA_TTL"))
	if raw == "" {
		return defaultAuthorityTTL
	}
	parsed, err := time.ParseDuration(raw)
	if err != nil || parsed <= 0 {
		return defaultAuthorityTTL
	}
	return parsed
}

func rotateBeforeDuration() time.Duration {
	raw := strings.TrimSpace(os.Getenv("MOHAWK_TPM_CA_ROTATE_BEFORE"))
	if raw == "" {
		return defaultAuthorityRotateBefore
	}
	parsed, err := time.ParseDuration(raw)
	if err != nil || parsed <= 0 {
		return defaultAuthorityRotateBefore
	}
	return parsed
}

func newAuthority(commonName string) (*Authority, error) {
	key, err := rsa.GenerateKey(rand.Reader, 3072)
	if err != nil {
		return nil, err
	}

	tmpl := &x509.Certificate{
		SerialNumber: big.NewInt(time.Now().UnixNano()),
		Subject: pkix.Name{
			CommonName:   commonName,
			Organization: []string{"Sovereign-Mohawk"},
		},
		NotBefore:             time.Now().Add(-1 * time.Minute),
		NotAfter:              time.Now().Add(authorityTTL()),
		IsCA:                  true,
		BasicConstraintsValid: true,
		KeyUsage:              x509.KeyUsageCertSign | x509.KeyUsageCRLSign,
	}
	der, err := x509.CreateCertificate(rand.Reader, tmpl, tmpl, &key.PublicKey, key)
	if err != nil {
		return nil, err
	}
	cert, err := x509.ParseCertificate(der)
	if err != nil {
		return nil, err
	}
	return &Authority{cert: cert, key: key}, nil
}

func newAttestor(nodeID string, authority *Authority) (*Attestor, error) {
	key, err := rsa.GenerateKey(rand.Reader, 3072)
	if err != nil {
		return nil, err
	}

	tmpl := &x509.Certificate{
		SerialNumber: big.NewInt(time.Now().UnixNano()),
		Subject: pkix.Name{
			CommonName:   nodeID,
			Organization: []string{"Sovereign-Mohawk Nodes"},
		},
		DNSNames:    []string{nodeID},
		NotBefore:   time.Now().Add(-1 * time.Minute),
		NotAfter:    time.Now().Add(12 * time.Hour),
		ExtKeyUsage: []x509.ExtKeyUsage{x509.ExtKeyUsageClientAuth, x509.ExtKeyUsageServerAuth},
		KeyUsage:    x509.KeyUsageDigitalSignature | x509.KeyUsageKeyEncipherment,
	}
	der, err := x509.CreateCertificate(rand.Reader, tmpl, authority.cert, &key.PublicKey, authority.key)
	if err != nil {
		return nil, err
	}
	leaf, err := x509.ParseCertificate(der)
	if err != nil {
		return nil, err
	}
	certPEM := pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der})
	keyPEM := pem.EncodeToMemory(&pem.Block{Type: "RSA PRIVATE KEY", Bytes: x509.MarshalPKCS1PrivateKey(key)})
	tlsCert, err := tls.X509KeyPair(certPEM, keyPEM)
	if err != nil {
		return nil, err
	}
	digest := sha256.Sum256([]byte("pcr:sha256:boot=measured;runtime=verified;node=" + nodeID))
	var hashSeed [32]byte
	if _, err := rand.Read(hashSeed[:]); err != nil {
		return nil, err
	}
	mode := ActiveAttestationSignatureMode()
	if mode == "" {
		return nil, fmt.Errorf("unsupported MOHAWK_TPM_IDENTITY_SIG_MODE %q", os.Getenv("MOHAWK_TPM_IDENTITY_SIG_MODE"))
	}
	return &Attestor{
		nodeID:    nodeID,
		authority: authority,
		tlsCert:   tlsCert,
		leafCert:  leaf,
		key:       key,
		pcrDigest: digest[:],
		sigMode:   mode,
		hashSeed:  hashSeed,
	}, nil
}

func (a *Attestor) GenerateQuote() ([]byte, error) {
	envelope := QuoteEnvelope{
		NodeID:         a.nodeID,
		PCRDigest:      append([]byte(nil), a.pcrDigest...),
		IssuedAt:       time.Now().UTC(),
		ExpiresAt:      time.Now().Add(5 * time.Minute).UTC(),
		SignatureAlgo:  string(a.sigMode),
		CertificatePEM: pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: a.leafCert.Raw}),
	}

	digest, err := envelope.payloadDigest()
	if err != nil {
		return nil, err
	}
	var signature []byte
	switch a.sigMode {
	case AttestationSignatureRSA:
		signature, err = rsa.SignPSS(rand.Reader, a.key, crypto.SHA256, digest, nil)
		if err != nil {
			return nil, err
		}
	case AttestationSignatureXMSS:
		a.sigMu.Lock()
		index := a.sigIndex
		a.sigIndex++
		a.sigMu.Unlock()
		signature, envelope.HashSigPublic = signStatefulHashDigest(a.hashSeed, index, digest)
		envelope.SignatureIndex = index
	default:
		return nil, fmt.Errorf("unsupported attestation signature mode %q", a.sigMode)
	}
	envelope.Signature = signature
	return json.Marshal(envelope)
}

const (
	hashSignatureBits      = 256
	hashSignatureWordBytes = 32
)

func signStatefulHashDigest(seed [32]byte, index uint64, digest []byte) ([]byte, []byte) {
	signature := make([]byte, 0, hashSignatureBits*hashSignatureWordBytes)
	publicKey := make([]byte, 0, hashSignatureBits*2*hashSignatureWordBytes)
	for bit := 0; bit < hashSignatureBits; bit++ {
		zeroSecret := deriveHashSignatureSecret(seed, index, bit, 0)
		oneSecret := deriveHashSignatureSecret(seed, index, bit, 1)
		zeroPub := sha256.Sum256(zeroSecret[:])
		onePub := sha256.Sum256(oneSecret[:])
		publicKey = append(publicKey, zeroPub[:]...)
		publicKey = append(publicKey, onePub[:]...)

		selected := zeroSecret
		if digestBit(digest, bit) == 1 {
			selected = oneSecret
		}
		signature = append(signature, selected[:]...)
	}
	return signature, publicKey
}

func verifyStatefulHashSignature(digest []byte, signature []byte, publicKey []byte) error {
	expectedSigLen := hashSignatureBits * hashSignatureWordBytes
	expectedPubLen := hashSignatureBits * 2 * hashSignatureWordBytes
	if len(signature) != expectedSigLen {
		return fmt.Errorf("signature length %d != %d", len(signature), expectedSigLen)
	}
	if len(publicKey) != expectedPubLen {
		return fmt.Errorf("public key length %d != %d", len(publicKey), expectedPubLen)
	}
	for bit := 0; bit < hashSignatureBits; bit++ {
		sigStart := bit * hashSignatureWordBytes
		sigEnd := sigStart + hashSignatureWordBytes
		hashed := sha256.Sum256(signature[sigStart:sigEnd])

		pubBase := bit * 2 * hashSignatureWordBytes
		if digestBit(digest, bit) == 0 {
			if !equalFixed32(publicKey[pubBase:pubBase+hashSignatureWordBytes], hashed[:]) {
				return fmt.Errorf("signature mismatch at bit %d", bit)
			}
		} else {
			oneStart := pubBase + hashSignatureWordBytes
			if !equalFixed32(publicKey[oneStart:oneStart+hashSignatureWordBytes], hashed[:]) {
				return fmt.Errorf("signature mismatch at bit %d", bit)
			}
		}
	}
	return nil
}

func deriveHashSignatureSecret(seed [32]byte, index uint64, bit int, choice byte) [32]byte {
	buf := make([]byte, 0, 32+8+2+1)
	buf = append(buf, seed[:]...)
	var indexBuf [8]byte
	binary.BigEndian.PutUint64(indexBuf[:], index)
	buf = append(buf, indexBuf[:]...)
	buf = append(buf, byte((bit>>8)&0xff), byte(bit&0xff), choice)
	return sha256.Sum256(buf)
}

func digestBit(digest []byte, bit int) byte {
	byteIdx := bit / 8
	bitIdx := uint(7 - (bit % 8))
	if (digest[byteIdx]>>bitIdx)&1 == 1 {
		return 1
	}
	return 0
}

func equalFixed32(a []byte, b []byte) bool {
	if len(a) != hashSignatureWordBytes || len(b) != hashSignatureWordBytes {
		return false
	}
	var diff byte
	for i := 0; i < hashSignatureWordBytes; i++ {
		diff |= a[i] ^ b[i]
	}
	return diff == 0
}

func (q QuoteEnvelope) payloadDigest() ([]byte, error) {
	payload := struct {
		NodeID    string    `json:"node_id"`
		PCRDigest []byte    `json:"pcr_digest"`
		IssuedAt  time.Time `json:"issued_at"`
		ExpiresAt time.Time `json:"expires_at"`
	}{
		NodeID:    q.NodeID,
		PCRDigest: q.PCRDigest,
		IssuedAt:  q.IssuedAt,
		ExpiresAt: q.ExpiresAt,
	}
	encoded, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}
	digest := sha256.Sum256(encoded)
	return digest[:], nil
}

func parseCertificate(pemBytes []byte) (*x509.Certificate, error) {
	block, _ := pem.Decode(pemBytes)
	if block == nil {
		return nil, fmt.Errorf("certificate is not valid PEM")
	}
	cert, err := x509.ParseCertificate(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("invalid certificate: %w", err)
	}
	return cert, nil
}
