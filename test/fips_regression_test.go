package test

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/fips140"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"math/big"
	"net"
	"os"
	"testing"
	"time"
)

func TestFIPSRegression(t *testing.T) {
	if os.Getenv("MOHAWK_REQUIRE_FIPS_MODE_FOR_TESTS") == "true" && !fips140.Enabled() {
		t.Fatalf("FIPS mode required for regression test but crypto/fips140 is disabled")
	}

	t.Run("tls-handshake", func(t *testing.T) {
		cert := generateSelfSignedTLSCert(t)
		ln, err := tls.Listen("tcp", "127.0.0.1:0", &tls.Config{Certificates: []tls.Certificate{cert}, MinVersion: tls.VersionTLS12})
		if err != nil {
			t.Fatalf("listen tls: %v", err)
		}
		defer ln.Close()

		errCh := make(chan error, 1)
		go func() {
			conn, err := ln.Accept()
			if err != nil {
				errCh <- err
				return
			}
			defer conn.Close()
			if _, err := conn.Write([]byte("ok")); err != nil {
				errCh <- err
				return
			}
			errCh <- nil
		}()

		client, err := tls.Dial("tcp", ln.Addr().String(), &tls.Config{InsecureSkipVerify: true, MinVersion: tls.VersionTLS12})
		if err != nil {
			t.Fatalf("dial tls: %v", err)
		}
		defer client.Close()

		buf := make([]byte, 2)
		if _, err := client.Read(buf); err != nil {
			t.Fatalf("read tls payload: %v", err)
		}
		if string(buf) != "ok" {
			t.Fatalf("unexpected tls payload %q", string(buf))
		}
		if err := <-errCh; err != nil {
			t.Fatalf("server side tls error: %v", err)
		}
	})

	t.Run("keygen-sign-verify", func(t *testing.T) {
		priv, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
		if err != nil {
			t.Fatalf("ecdsa keygen failed: %v", err)
		}
		digest := []byte("mohawk-fips-regression")
		sig, err := ecdsa.SignASN1(rand.Reader, priv, digest)
		if err != nil {
			t.Fatalf("ecdsa sign failed: %v", err)
		}
		if !ecdsa.VerifyASN1(&priv.PublicKey, digest, sig) {
			t.Fatal("ecdsa verify failed")
		}
	})
}

func generateSelfSignedTLSCert(t *testing.T) tls.Certificate {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("tls keygen failed: %v", err)
	}

	tmpl := &x509.Certificate{
		SerialNumber: big.NewInt(1),
		Subject:      pkix.Name{CommonName: "localhost"},
		NotBefore:    time.Now().Add(-1 * time.Minute),
		NotAfter:     time.Now().Add(10 * time.Minute),
		KeyUsage:     x509.KeyUsageDigitalSignature | x509.KeyUsageKeyEncipherment,
		ExtKeyUsage:  []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
		DNSNames:     []string{"localhost"},
		IPAddresses:  []net.IP{net.ParseIP("127.0.0.1")},
	}

	der, err := x509.CreateCertificate(rand.Reader, tmpl, tmpl, &key.PublicKey, key)
	if err != nil {
		t.Fatalf("create tls cert failed: %v", err)
	}

	certPEM := pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der})
	pk, err := x509.MarshalECPrivateKey(key)
	if err != nil {
		t.Fatalf("marshal tls private key failed: %v", err)
	}
	keyPEM := pem.EncodeToMemory(&pem.Block{Type: "EC PRIVATE KEY", Bytes: pk})

	cert, err := tls.X509KeyPair(certPEM, keyPEM)
	if err != nil {
		t.Fatalf("x509 key pair failed: %v", err)
	}
	return cert
}
