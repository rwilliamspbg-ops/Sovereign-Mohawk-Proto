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
	"crypto/fips140"
	"fmt"
	"os"
)

func main() {
	if !fips140.Enabled() {
		fmt.Fprintln(os.Stderr, "FIPS runtime check failed: crypto/fips140 is disabled")
		os.Exit(1)
	}

	fmt.Println("FIPS runtime check passed: crypto/fips140 is enabled")
}
