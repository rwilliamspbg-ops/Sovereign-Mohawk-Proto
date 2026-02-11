import json
import re
import sys

def extract_go_functions(file_path):
    # Regex to find host function registrations in your Go code
    # Adjust this based on your specific implementation (e.g., Wasmtime's Linker.Define)
    pattern = re.compile(r'linker\.Define\("env",\s*"([^"]+)"')
    with open(file_path, 'r') as f:
        return set(pattern.findall(f.read()))

def validate():
    with open('capabilities.json', 'r') as f:
        capabilities = json.load(f)
    
    # Flatten the exposed_functions categories for comparison
    json_functions = set()
    for category in capabilities.get('exposed_functions', {}).values():
        json_functions.update(category.keys())

    # Path to your main wasmhost logic
    go_functions = extract_go_functions('internal/wasmhost/host.go')

    missing_in_json = go_functions - json_functions
    if missing_in_json:
        print(f"❌ Error: Functions defined in Go but missing in capabilities.json: {missing_in_json}")
        sys.exit(1)
    
    print("✅ Sync check passed: capabilities.json is up to date.")

if __name__ == "__main__":
    validate()
