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
	"crypto/fips140"
	"fmt"
	"log"
	"os"
	"strings"
)

func fipsRequiredFromEnv() bool {
	raw := strings.TrimSpace(strings.ToLower(os.Getenv("MOHAWK_FIPS_REQUIRED")))
	switch raw {
	case "1", "true", "yes", "on", "required":
		return true
	default:
		return false
	}
}

// EnforceFIPSGate fails startup when FIPS is required but the runtime is not in FIPS mode.
func EnforceFIPSGate(component string) error {
	if !fipsRequiredFromEnv() {
		return nil
	}
	if !fips140.Enabled() {
		return fmt.Errorf("%s startup blocked: MOHAWK_FIPS_REQUIRED=true but crypto/fips140 is disabled; set GODEBUG=fips140=on or fips140=only", component)
	}
	return nil
}

// LogRuntimeMetadata prints startup metadata and FIPS posture at boot.
func LogRuntimeMetadata(component, version, commit, buildDate string) {
	log.Printf("%s runtime metadata version=%s commit=%s build_date=%s fips_enabled=%t", component, version, commit, buildDate, fips140.Enabled())
}
