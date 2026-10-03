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

package startup

import (
	"bytes"
	"crypto/fips140"
	"log"
	"os"
	"strings"
	"testing"
)

func TestFipsRequiredFromEnv(t *testing.T) {
	tests := []struct {
		envVal   string
		expected bool
	}{
		{"1", true},
		{"true", true},
		{"TRUE", true},
		{" yes ", true},
		{"on", true},
		{"required", true},
		{"0", false},
		{"false", false},
		{"no", false},
		{"off", false},
		{"", false},
		{"other", false},
	}

	for _, tt := range tests {
		t.Run("env_"+tt.envVal, func(t *testing.T) {
			t.Setenv("MOHAWK_FIPS_REQUIRED", tt.envVal)
			got := fipsRequiredFromEnv()
			if got != tt.expected {
				t.Errorf("fipsRequiredFromEnv() with MOHAWK_FIPS_REQUIRED=%q: got %v, want %v", tt.envVal, got, tt.expected)
			}
		})
	}
}

func TestEnforceFIPSGate(t *testing.T) {
	t.Run("FIPS not required", func(t *testing.T) {
		t.Setenv("MOHAWK_FIPS_REQUIRED", "false")
		err := EnforceFIPSGate("my-component")
		if err != nil {
			t.Errorf("expected no error when FIPS is not required, got: %v", err)
		}
	})

	t.Run("FIPS required", func(t *testing.T) {
		t.Setenv("MOHAWK_FIPS_REQUIRED", "true")
		err := EnforceFIPSGate("my-component")
		if fips140.Enabled() {
			if err != nil {
				t.Errorf("expected no error when fips140.Enabled() is true, got: %v", err)
			}
		} else {
			if err == nil {
				t.Errorf("expected error when FIPS is required but fips140.Enabled() is false, got nil")
			} else if !strings.Contains(err.Error(), "my-component startup blocked") {
				t.Errorf("expected error message to contain component name, got: %v", err)
			}
		}
	})
}

func TestLogRuntimeMetadata(t *testing.T) {
	var buf bytes.Buffer
	log.SetOutput(&buf)
	defer log.SetOutput(os.Stderr)

	component := "test-node"
	version := "1.2.3"
	commit := "deadbeef"
	buildDate := "2026-03-30"

	LogRuntimeMetadata(component, version, commit, buildDate)

	output := buf.String()
	for _, substr := range []string{component, version, commit, buildDate, "runtime metadata"} {
		if !strings.Contains(output, substr) {
			t.Errorf("expected log output to contain %q, output was: %s", substr, output)
		}
	}
}
