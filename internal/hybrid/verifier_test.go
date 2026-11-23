package hybrid

import (
	"context"
	"errors"
	"sort"
	"strings"
	"testing"

	internalpkg "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

type fakeSTARKVerifier struct {
	name string
	ok   bool
	err  error
}

func (f fakeSTARKVerifier) BackendName() string         { return f.name }
func (f fakeSTARKVerifier) Verify([]byte) (bool, error) { return f.ok, f.err }

type unnamedSTARKVerifier struct{}

func (unnamedSTARKVerifier) BackendName() string         { return "" }
func (unnamedSTARKVerifier) Verify([]byte) (bool, error) { return true, nil }

type fakeAccelerator struct {
	name  string
	ok    bool
	err   error
	calls int
}

func (f *fakeAccelerator) BackendName() string { return f.name }
func (f *fakeAccelerator) Verify(ctx context.Context, proof []byte) (bool, error) {
	f.calls++
	return f.ok, f.err
}

func containsString(xs []string, want string) bool {
	for _, x := range xs {
		if x == want {
			return true
		}
	}
	return false
}

func equalStrings(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func TestFRIVerifierVerify(t *testing.T) {
	content := []byte("0123456789abcdef0123456789abcdef") // 32 bytes
	valid := GenFRIProof(content)

	tampered := append([]byte(nil), valid...)
	tampered[len(tampered)-1] ^= 0xff

	badRoot := append([]byte(nil), valid...)
	badRoot[0] ^= 0xff

	cases := []struct {
		name    string
		proof   []byte
		wantOK  bool
		wantErr string
	}{
		{"empty proof", nil, false, "stark proof missing"},
		{"too short", make([]byte, 63), false, "stark proof too short"},
		{"minimum length", valid, true, ""},
		{"tampered content", tampered, false, "FRI commitment mismatch"},
		{"tampered root", badRoot, false, "FRI commitment mismatch"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			ok, err := (friVerifier{}).Verify(tc.proof)
			if tc.wantErr == "" {
				if err != nil {
					t.Fatalf("Verify: %v", err)
				}
				if !ok {
					t.Error("Verify = false, want true")
				}
				return
			}
			if err == nil {
				t.Fatalf("Verify = (true, nil), want an error containing %q", tc.wantErr)
			}
			if !strings.Contains(err.Error(), tc.wantErr) {
				t.Errorf("error = %q, want it to contain %q", err, tc.wantErr)
			}
			if ok {
				t.Error("Verify = true on an error path")
			}
		})
	}
}

func TestGenFRIProofLayout(t *testing.T) {
	content := []byte("0123456789abcdef0123456789abcdef") // 32 bytes
	proof := GenFRIProof(content)
	if len(proof) != 32+len(content) {
		t.Fatalf("len = %d, want %d", len(proof), 32+len(content))
	}
	if ok, err := (friVerifier{}).Verify(proof); err != nil || !ok {
		t.Fatalf("round trip: ok=%v err=%v", ok, err)
	}

	// Boundary: content below 32 bytes cannot satisfy the minimum proof size.
	for _, n := range []int{0, 1, 31} {
		p := GenFRIProof(make([]byte, n))
		if len(p) >= 64 {
			t.Errorf("content of %d bytes produced a %d-byte proof, want < 64", n, len(p))
		}
		if ok, err := (friVerifier{}).Verify(p); err == nil || ok {
			t.Errorf("content of %d bytes: Verify = (%v, %v), want an error", n, ok, err)
		}
	}

	// Exactly 32 bytes of content is the minimum that verifies.
	min := GenFRIProof(make([]byte, 32))
	if ok, err := (friVerifier{}).Verify(min); err != nil || !ok {
		t.Errorf("minimum-length proof: ok=%v err=%v", ok, err)
	}
}

func TestWinterfellVerifierVerify(t *testing.T) {
	content := []byte("0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef") // 64 bytes
	valid := GenWinterfellProof(content)

	tampered := append([]byte(nil), valid...)
	tampered[len(tampered)-1] ^= 0xff

	// A FRI proof is a valid Merkle commitment but lacks the winterfell-v1
	// domain separator, so it must not verify here.
	friStyle := GenFRIProof(content)

	cases := []struct {
		name    string
		proof   []byte
		wantOK  bool
		wantErr string
	}{
		{"empty proof", nil, false, "winterfell stark proof missing"},
		{"too short", make([]byte, 95), false, "winterfell proof too short"},
		{"minimum length", valid, true, ""},
		{"tampered transcript", tampered, false, "winterfell commitment mismatch"},
		{"fri proof replay", friStyle, false, "winterfell commitment mismatch"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			ok, err := (winterfellVerifier{}).Verify(tc.proof)
			if tc.wantErr == "" {
				if err != nil {
					t.Fatalf("Verify: %v", err)
				}
				if !ok {
					t.Error("Verify = false, want true")
				}
				return
			}
			if err == nil {
				t.Fatalf("Verify = (true, nil), want an error containing %q", tc.wantErr)
			}
			if !strings.Contains(err.Error(), tc.wantErr) {
				t.Errorf("error = %q, want it to contain %q", err, tc.wantErr)
			}
			if ok {
				t.Error("Verify = true on an error path")
			}
		})
	}
}

func TestGenWinterfellProofDomainSeparation(t *testing.T) {
	transcript := []byte("0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")
	proof := GenWinterfellProof(transcript)
	if len(proof) != 32+len(transcript) {
		t.Fatalf("len = %d, want %d", len(proof), 32+len(transcript))
	}
	if ok, err := (winterfellVerifier{}).Verify(proof); err != nil || !ok {
		t.Fatalf("round trip: ok=%v err=%v", ok, err)
	}
	// The same bytes must not satisfy the FRI backend: the domain separator is
	// what keeps the two proof systems from accepting each other's proofs.
	if ok, _ := (friVerifier{}).Verify(proof); ok {
		t.Error("a winterfell proof verified under the FRI backend; the domain separator is not load-bearing")
	}
}

func TestRegisterSTARKBackendAndAvailable(t *testing.T) {
	orig, _, err := resolveSTARKBackend("simulated_fri")
	if err != nil {
		t.Fatalf("resolve simulated_fri: %v", err)
	}
	defer RegisterSTARKBackend(orig)

	// nil and unnamed verifiers must be ignored rather than panic or register.
	RegisterSTARKBackend(nil)
	RegisterSTARKBackend(unnamedSTARKVerifier{})

	names := AvailableSTARKBackends()
	if !sort.StringsAreSorted(names) {
		t.Errorf("AvailableSTARKBackends not sorted: %v", names)
	}
	for _, want := range []string{"simulated_fri", "winterfell_mock"} {
		if !containsString(names, want) {
			t.Errorf("AvailableSTARKBackends = %v, want it to contain %q", names, want)
		}
	}

	RegisterSTARKBackend(fakeSTARKVerifier{name: "zz-test-backend"})
	names = AvailableSTARKBackends()
	if !containsString(names, "zz-test-backend") {
		t.Errorf("AvailableSTARKBackends = %v, want the newly registered backend", names)
	}

	// Registering an existing name replaces rather than duplicates.
	RegisterSTARKBackend(fakeSTARKVerifier{name: "simulated_fri", ok: false})
	v, name, err := resolveSTARKBackend("simulated_fri")
	if err != nil {
		t.Fatalf("resolve after replace: %v", err)
	}
	if name != "simulated_fri" {
		t.Errorf("name = %q", name)
	}
	if _, isFake := v.(fakeSTARKVerifier); !isFake {
		t.Errorf("resolved %T, want the replacement fakeSTARKVerifier", v)
	}
}

func TestResolveSTARKBackend(t *testing.T) {
	if _, name, err := resolveSTARKBackend("winterfell_mock"); err != nil || name != "winterfell_mock" {
		t.Errorf("explicit name: (%q, %v)", name, err)
	}

	t.Run("unknown", func(t *testing.T) {
		if _, _, err := resolveSTARKBackend("no-such-backend"); err == nil {
			t.Error("expected an error for an unknown backend")
		}
	})

	t.Run("env default", func(t *testing.T) {
		t.Setenv("MOHAWK_DEFAULT_STARK_BACKEND", "winterfell_mock")
		_, name, err := resolveSTARKBackend("")
		if err != nil {
			t.Fatalf("resolve with env default: %v", err)
		}
		if name != "winterfell_mock" {
			t.Errorf("name = %q, want winterfell_mock", name)
		}
	})

	t.Run("env default unknown", func(t *testing.T) {
		t.Setenv("MOHAWK_DEFAULT_STARK_BACKEND", "no-such-backend")
		if _, _, err := resolveSTARKBackend(""); err == nil {
			t.Error("expected an error for an unknown env-configured backend")
		}
	})

	t.Run("empty falls back to simulated_fri", func(t *testing.T) {
		t.Setenv("MOHAWK_DEFAULT_STARK_BACKEND", "")
		_, name, err := resolveSTARKBackend("")
		if err != nil {
			t.Fatalf("resolve default: %v", err)
		}
		if name != "simulated_fri" {
			t.Errorf("name = %q, want simulated_fri", name)
		}
	})
}

func TestVerifyHybridModeMatrix(t *testing.T) {
	validSNARK := internalpkg.GenesisProofBytes()
	validSTARK := GenFRIProof([]byte("0123456789abcdef0123456789abcdef"))

	cases := []struct {
		name       string
		mode       HybridMode
		snark      []byte
		stark      []byte
		wantAccept bool
		wantSNARK  bool
		wantSTARK  bool
		wantErr    bool
	}{
		{"both valid, ModeBoth", ModeBoth, validSNARK, validSTARK, true, true, true, false},
		{"both valid, ModeAny", ModeAny, validSNARK, validSTARK, true, true, true, false},
		{"both valid, ModePreferSNARK", ModePreferSNARK, validSNARK, validSTARK, true, true, true, false},
		{"only stark valid, ModeBoth", ModeBoth, nil, validSTARK, false, false, true, true},
		{"only stark valid, ModeAny", ModeAny, nil, validSTARK, true, false, true, false},
		{"only stark valid, ModePreferSNARK", ModePreferSNARK, nil, validSTARK, true, false, true, false},
		{"only snark valid, ModeBoth", ModeBoth, validSNARK, nil, false, true, false, true},
		{"only snark valid, ModeAny", ModeAny, validSNARK, nil, true, true, false, false},
		{"both invalid, ModeAny", ModeAny, nil, nil, false, false, false, true},
		{"default mode", "", validSNARK, validSTARK, true, true, true, false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			res, err := VerifyHybrid(VerifyRequest{Mode: tc.mode, SNARKProof: tc.snark, STARKProof: tc.stark})
			if tc.wantErr {
				if err == nil {
					t.Fatalf("expected an error, got result %+v", res)
				}
				return
			}
			if err != nil {
				t.Fatalf("VerifyHybrid: %v", err)
			}
			if res.Accepted != tc.wantAccept {
				t.Errorf("Accepted = %v, want %v", res.Accepted, tc.wantAccept)
			}
			if res.SNARKValid != tc.wantSNARK {
				t.Errorf("SNARKValid = %v, want %v", res.SNARKValid, tc.wantSNARK)
			}
			if res.STARKValid != tc.wantSTARK {
				t.Errorf("STARKValid = %v, want %v", res.STARKValid, tc.wantSTARK)
			}
			if tc.mode == "" && res.Policy != string(ModePreferSNARK) {
				t.Errorf("Policy = %q, want prefer_snark", res.Policy)
			}
		})
	}
}

func TestVerifyHybridRejectsUnknownModeAndBackend(t *testing.T) {
	validSTARK := GenFRIProof([]byte("0123456789abcdef0123456789abcdef"))

	t.Run("unknown mode", func(t *testing.T) {
		_, err := VerifyHybrid(VerifyRequest{
			Mode:       "bogus",
			SNARKProof: internalpkg.GenesisProofBytes(),
			STARKProof: validSTARK,
		})
		if err == nil {
			t.Fatal("expected an error for an unsupported hybrid mode")
		}
		if !strings.Contains(err.Error(), "unsupported hybrid mode") {
			t.Errorf("error = %q", err)
		}
	})

	t.Run("unknown stark backend", func(t *testing.T) {
		_, err := VerifyHybrid(VerifyRequest{
			Mode:         ModeAny,
			SNARKProof:   internalpkg.GenesisProofBytes(),
			STARKProof:   validSTARK,
			STARKBackend: "no-such-backend",
		})
		if err == nil {
			t.Fatal("expected an error for an unknown STARK backend")
		}
	})
}

func TestVerifyHybridJoinsVerifierErrors(t *testing.T) {
	_, err := VerifyHybrid(VerifyRequest{Mode: ModeBoth, SNARKProof: nil, STARKProof: make([]byte, 10)})
	if err == nil {
		t.Fatal("expected an error")
	}
	for _, want := range []string{"hybrid policy", "snark proof missing", "stark proof too short"} {
		if !strings.Contains(err.Error(), want) {
			t.Errorf("joined error = %q, want it to contain %q", err, want)
		}
	}
}

func TestVerifyHybridSNARKAcceleratorRouting(t *testing.T) {
	validSTARK := GenFRIProof([]byte("0123456789abcdef0123456789abcdef"))
	genesis := internalpkg.GenesisProofBytes()

	t.Run("accelerator success is used", func(t *testing.T) {
		acc := &fakeAccelerator{name: "fake-accel", ok: true}
		RegisterSNARKAccelerator(acc)
		defer RegisterSNARKAccelerator(nil)

		res, err := VerifyHybrid(VerifyRequest{Mode: ModeBoth, SNARKProof: []byte("opaque"), STARKProof: validSTARK})
		if err != nil {
			t.Fatalf("VerifyHybrid: %v", err)
		}
		if !res.SNARKValid || res.SNARKBackend != "fake-accel" {
			t.Errorf("SNARKValid=%v backend=%q, want true/fake-accel", res.SNARKValid, res.SNARKBackend)
		}
		if acc.calls != 1 {
			t.Errorf("accelerator calls = %d, want 1", acc.calls)
		}
	})

	t.Run("accelerator failure falls back to CPU", func(t *testing.T) {
		acc := &fakeAccelerator{name: "fake-accel", err: errors.New("boom")}
		RegisterSNARKAccelerator(acc)
		defer RegisterSNARKAccelerator(nil)

		res, err := VerifyHybrid(VerifyRequest{Mode: ModeBoth, SNARKProof: genesis, STARKProof: validSTARK})
		if err != nil {
			t.Fatalf("VerifyHybrid: %v", err)
		}
		if !res.SNARKValid {
			t.Error("SNARKValid = false, want the CPU fallback to verify the genesis proof")
		}
		if res.SNARKBackend != "cpu_fallback" {
			t.Errorf("SNARKBackend = %q, want cpu_fallback", res.SNARKBackend)
		}
	})

	t.Run("commitment bypasses the accelerator", func(t *testing.T) {
		acc := &fakeAccelerator{name: "fake-accel", ok: true}
		RegisterSNARKAccelerator(acc)
		defer RegisterSNARKAccelerator(nil)

		preimage := internalpkg.DataCommitmentDigest([]byte("accel-routing-round"))
		proofBytes, commitment, err := internalpkg.ProveDataCommitment(preimage)
		if err != nil {
			t.Fatalf("ProveDataCommitment: %v", err)
		}

		res, err := VerifyHybrid(VerifyRequest{
			Mode:       ModeBoth,
			SNARKProof: proofBytes,
			Commitment: "0x" + commitment.Text(16),
			STARKProof: validSTARK,
		})
		if err != nil {
			t.Fatalf("VerifyHybrid: %v", err)
		}
		if res.SNARKBackend != "cpu" {
			t.Errorf("SNARKBackend = %q, want cpu: a commitment-bound request must not use the accelerator", res.SNARKBackend)
		}
		if acc.calls != 0 {
			t.Errorf("accelerator calls = %d, want 0 for a commitment-bound request", acc.calls)
		}
		if !res.SNARKValid {
			t.Error("SNARKValid = false, want true")
		}
	})

	t.Run("accelerator reporting false is honoured", func(t *testing.T) {
		acc := &fakeAccelerator{name: "fake-accel", ok: false}
		RegisterSNARKAccelerator(acc)
		defer RegisterSNARKAccelerator(nil)

		res, err := VerifyHybrid(VerifyRequest{Mode: ModePreferSNARK, SNARKProof: []byte("opaque"), STARKProof: validSTARK})
		if err != nil {
			t.Fatalf("VerifyHybrid: %v", err)
		}
		if res.SNARKValid {
			t.Error("SNARKValid = true, want false")
		}
		if !res.STARKValid || !res.Accepted {
			t.Errorf("ModePreferSNARK with a valid STARK proof should still accept: %+v", res)
		}
	})
}

func TestParseExternalCommand(t *testing.T) {
	cases := []struct {
		name     string
		raw      string
		wantBin  string
		wantArgs []string
		wantErr  string
	}{
		{"empty", "", "", nil, "external command is not configured"},
		{"whitespace only", "   ", "", nil, "external command is not configured"},
		{"pipe", "sed | ls", "", nil, "shell metacharacters"},
		{"ampersand", "sed&&ls", "", nil, "shell metacharacters"},
		{"semicolon", "sed;ls", "", nil, "shell metacharacters"},
		{"less than", "sed<ls", "", nil, "shell metacharacters"},
		{"greater than", "sed>out", "", nil, "shell metacharacters"},
		{"backtick", "sed`id`", "", nil, "shell metacharacters"},
		{"backslash", "sed\\ls", "", nil, "shell metacharacters"},
		{"newline splits fields", "sed\nls", "", nil, "not allowlisted"},
		{"carriage return splits fields", "sed\rls", "", nil, "not allowlisted"},
		{"unallowlisted binary", "sed", "", nil, "not allowlisted"},
		{"unallowlisted with path", "/opt/sed", "", nil, "not allowlisted"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			bin, args, err := parseExternalCommand(tc.raw)
			if tc.wantErr != "" {
				if err == nil {
					t.Fatalf("expected an error containing %q, got bin=%q args=%v", tc.wantErr, bin, args)
				}
				if !strings.Contains(err.Error(), tc.wantErr) {
					t.Errorf("error = %q, want it to contain %q", err, tc.wantErr)
				}
				return
			}
			if err != nil {
				t.Fatalf("parseExternalCommand(%q): %v", tc.raw, err)
			}
			if bin != tc.wantBin {
				t.Errorf("bin = %q, want %q", bin, tc.wantBin)
			}
			if !equalStrings(args, tc.wantArgs) {
				t.Errorf("args = %v, want %v", args, tc.wantArgs)
			}
		})
	}
}

// The metacharacter denylist in parseExternalCommand is over-escaped: its
// source literal "...`\\\\n\\\\r" decodes to a set containing backslash and
// the letters 'n' and 'r' (the intended newline and CR escapes were escaped
// away). Every allowlisted binary (python, python3, node, stark-verify,
// snark-verify, winterfell-verify) contains 'n' or 'r', so no allowlisted
// command can currently pass the check and the allowlist branch is only
// reachable for non-allowlisted names. This pins that behaviour; if the
// escaping is fixed, these cases must be updated.
func TestParseExternalCommandOverEscapedDenylist(t *testing.T) {
	for _, raw := range []string{"node", "python3 x.py", "stark-verify"} {
		_, _, err := parseExternalCommand(raw)
		if err == nil {
			t.Errorf("parseExternalCommand(%q) succeeded, want the over-escaped denylist to reject it", raw)
			continue
		}
		if !strings.Contains(err.Error(), "shell metacharacters") {
			t.Errorf("parseExternalCommand(%q) error = %q, want shell metacharacters", raw, err)
		}
	}
}

func TestSanitizeExternalExecutable(t *testing.T) {
	cases := []struct {
		name    string
		raw     string
		want    string
		wantErr string
	}{
		{"empty", "", "", "external executable is empty"},
		{"whitespace", "   ", "", "external executable is empty"},
		{"nul byte", "python3\x00", "", "NUL byte"},
		{"dot", ".", "", "external executable is invalid"},
		{"unallowlisted", "notepad.exe", "", "not allowlisted"},
		{"allowlisted", "python3", "python3", ""},
		{"allowlisted with path", "/usr/bin/node", "node", ""},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, err := sanitizeExternalExecutable(tc.raw)
			if tc.wantErr != "" {
				if err == nil {
					t.Fatalf("expected an error containing %q, got %q", tc.wantErr, got)
				}
				if !strings.Contains(err.Error(), tc.wantErr) {
					t.Errorf("error = %q, want it to contain %q", err, tc.wantErr)
				}
				return
			}
			if err != nil {
				t.Fatalf("sanitizeExternalExecutable(%q): %v", tc.raw, err)
			}
			if got != tc.want {
				t.Errorf("got %q, want %q", got, tc.want)
			}
		})
	}
}

func TestExternalBackendNames(t *testing.T) {
	if got := (externalCommandVerifier{}).BackendName(); got != "external_cmd" {
		t.Errorf("externalCommandVerifier.BackendName = %q, want external_cmd", got)
	}
	if got := (externalSNARKAccelerator{}).BackendName(); got != "external_accelerator" {
		t.Errorf("externalSNARKAccelerator.BackendName = %q, want external_accelerator", got)
	}
}

func TestExternalCommandVerifierInputValidation(t *testing.T) {
	cases := []struct {
		name    string
		command string
		proof   []byte
		wantErr string
	}{
		{"empty proof", "python3 x.py", nil, "external stark proof missing"},
		{"empty command", "", []byte("proof"), "external stark verify command is not configured"},
		{"whitespace command", "   ", []byte("proof"), "external stark verify command is not configured"},
		{"metacharacter command", "python3 | rm", []byte("proof"), "shell metacharacters"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			v := externalCommandVerifier{command: tc.command}
			ok, err := v.Verify(tc.proof)
			if err == nil {
				t.Fatalf("Verify = (%v, nil), want an error containing %q", ok, tc.wantErr)
			}
			if !strings.Contains(err.Error(), tc.wantErr) {
				t.Errorf("error = %q, want it to contain %q", err, tc.wantErr)
			}
			if ok {
				t.Error("ok = true on an error path")
			}
		})
	}
}

func TestExternalSNARKAcceleratorInputValidation(t *testing.T) {
	cases := []struct {
		name    string
		command string
		proof   []byte
		wantErr string
	}{
		{"empty proof", "python3 x.py", nil, "accelerated snark proof missing"},
		{"empty command", "", []byte("proof"), "accelerated snark command is not configured"},
		{"metacharacter command", "python3 | rm", []byte("proof"), "shell metacharacters"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			v := externalSNARKAccelerator{command: tc.command}
			ok, err := v.Verify(context.Background(), tc.proof)
			if err == nil {
				t.Fatalf("Verify = (%v, nil), want an error containing %q", ok, tc.wantErr)
			}
			if !strings.Contains(err.Error(), tc.wantErr) {
				t.Errorf("error = %q, want it to contain %q", err, tc.wantErr)
			}
			if ok {
				t.Error("ok = true on an error path")
			}
		})
	}
}
