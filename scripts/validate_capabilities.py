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
import sys


def validate_capabilities():
    file_path = "capabilities.json"

    if not os.path.exists(file_path):
        print(f"CRITICAL: {file_path} not found.")
        sys.exit(1)

    try:
        with open(file_path, "r") as f:
            data = json.load(f)

        # 1. Check for required keys in your Mohawk architecture
        required_keys = ["version", "nodes", "fl_vote_threshold", "runtime"]
        for key in required_keys:
            if key not in data:
                print(f"ERROR: Missing required key '{key}' in capabilities.json")
                sys.exit(1)

        # 2. FL vote threshold: majority required for aggregation acceptance.
        fl_vote = data.get("fl_vote_threshold", 0)
        if fl_vote < 0.5:
            print(
                f"ERROR: fl_vote_threshold {fl_vote} is below 0.5 (no majority guarantee)"
            )
            sys.exit(1)

        # 3. BFT safety bound from cluster configuration (f/n < 1/3).
        cc = data.get("cluster_config", {})
        n = cc.get("node_count", 0)
        f = cc.get("max_byzantine_nodes", 0)
        if n > 0 and f / n >= 1 / 3:
            print(f"SECURITY ALERT: f/n = {f / n:.3f} >= 1/3 violates BFT safety")
            sys.exit(1)

        # 4. Structural Validation: Node Configuration
        if not isinstance(data.get("nodes"), list) or len(data["nodes"]) == 0:
            print("ERROR: 'nodes' must be a non-empty list.")
            sys.exit(1)

        print("SUCCESS: capabilities.json passed all sync checks.")

    except json.JSONDecodeError as e:
        print(f"JSON ERROR: Failed to parse capabilities.json: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"UNEXPECTED ERROR: {e}")
        sys.exit(1)


if __name__ == "__main__":
    validate_capabilities()
