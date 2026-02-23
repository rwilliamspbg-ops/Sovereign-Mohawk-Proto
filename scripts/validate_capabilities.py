# Copyright 2026 Ryan Williams / Sovereign Mohawk Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import json
import os
import re
import sys


def extract_go_functions(file_path):
    """Regex to find host function registrations in your Go code."""
    if not os.path.exists(file_path):
        print(f"⚠️ Warning: Source file {file_path} not found.")
        return set()

    # Pattern looks for linker.Define("env", "function_name", ...)
    pattern = re.compile(r'linker\.Define\("env",\s*"([^"]+)"')
    with open(file_path, "r", encoding="utf-8") as f:
        return set(pattern.findall(f.read()))


def validate():
    """Main validation logic for capabilities and host sync."""
    capabilities_path = "capabilities.json"
    host_logic_path = "internal/wasmhost/host.go"

    if not os.path.exists(capabilities_path):
        print(f"❌ Error: {capabilities_path} missing.")
        sys.exit(1)

    with open(capabilities_path, "r", encoding="utf-8") as f:
        capabilities = json.load(f)

    # Flatten the exposed_functions categories for comparison
    json_functions = set()
    exposed = capabilities.get("exposed_functions", {})
    for category in exposed.values():
        if isinstance(category, dict):
            json_functions.update(category.keys())

    # Extract functions defined in the Go host
    go_functions = extract_go_functions(host_logic_path)

    if not go_functions:
        print(f"⚠️ No functions found in {host_logic_path}. Check regex.")
        return

    missing_in_json = go_functions - json_functions
    if missing_in_json:
        print(
            f"❌ Error: Functions defined in Go but missing in "
            f"capabilities.json: {missing_in_json}"
        )
        sys.exit(1)

    print("✅ Sync check passed: capabilities.json is up to date with host.go.")


if __name__ == "__main__":
    validate()
