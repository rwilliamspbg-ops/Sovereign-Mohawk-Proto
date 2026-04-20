#!/usr/bin/env python3
"""Verify formal proof system and validate test suite."""

import json
import os
import re
from pathlib import Path

def test_traceability_matrix():
    """Validate formal traceability matrix structure and content."""
    print('\n=== Formal Proof Traceability Matrix Validation ===\n')
    
    matrix_file = 'proofs/FORMAL_TRACEABILITY_MATRIX.md'
    if not os.path.exists(matrix_file):
        print('FAIL: Matrix file not found')
        return False
    
    with open(matrix_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    print('PASS: Matrix file exists ({} chars)'.format(len(content)))
    
    # Check for 6 theorems in traceability table rows
    theorem_patterns = [
        (r'\| 1 \|', 'Byzantine resilience'),
        (r'\| 2 \|', 'RDP composition'),
        (r'\| 3 \|', 'Communication'),
        (r'\| 4 \|', 'Liveness'),
        (r'\| 5 \|', 'Cryptography'),
        (r'\| 6 \|', 'Convergence'),
    ]
    
    print('\nTheorem Mapping Status:')
    all_found = True
    for pattern, desc in theorem_patterns:
        if re.search(pattern, content):
            print('  PASS {}: {}'.format(pattern, desc))
        else:
            print('  FAIL {}: {} - MISSING'.format(pattern, desc))
            all_found = False
    
    # Check for required Lean modules
    lean_modules = [
        'Theorem1BFT.lean',
        'Theorem2RDP.lean',
        'Theorem3Communication.lean',
        'Theorem4Liveness.lean',
        'Theorem5Cryptography.lean',
        'Theorem6Convergence.lean',
    ]
    
    print('\nLean Module References:')
    for module in lean_modules:
        if module in content:
            print('  PASS {}'.format(module))
        else:
            print('  FAIL {} - MISSING'.format(module))
            all_found = False
    
    # Check sections
    sections = ['Lean Module', 'Runtime Test Evidence', 'Status', 'Verified']
    print('\nTraceability Sections:')
    for section in sections:
        if section in content:
            print('  PASS {}'.format(section))
        else:
            print('  FAIL {} - MISSING'.format(section))
            all_found = False
    
    # Count theorem entries
    theorem_rows = len(re.findall(r'\| \d+ \|', content))
    print('\nTotal theorem mappings: {}'.format(theorem_rows))
    
    if theorem_rows != 6:
        print('FAIL: Expected 6 theorems, found {}'.format(theorem_rows))
        all_found = False
    else:
        print('PASS: All 6 theorems mapped')
    
    return all_found

def test_lean_modules():
    """Verify Lean formalization modules exist and are non-empty."""
    print('\n=== Lean Formalization Files ===\n')
    
    lean_dir = 'proofs/LeanFormalization'
    if not os.path.isdir(lean_dir):
        print('FAIL: Lean directory not found')
        return False
    
    required_modules = [
        'Theorem1BFT.lean',
        'Theorem2RDP.lean',
        'Theorem3Communication.lean',
        'Theorem4Liveness.lean',
        'Theorem5Cryptography.lean',
        'Theorem6Convergence.lean',
        'Common.lean',
    ]
    
    lean_files = sorted([f for f in os.listdir(lean_dir) if f.endswith('.lean')])
    print('PASS: Found {} Lean modules:'.format(len(lean_files)))
    
    all_ok = True
    for required in required_modules:
        if required in lean_files:
            fpath = os.path.join(lean_dir, required)
            size = os.path.getsize(fpath)
            if size > 0:
                print('  PASS {} ({} bytes)'.format(required, size))
            else:
                print('  FAIL {} is empty'.format(required))
                all_ok = False
        else:
            print('  FAIL {} - MISSING'.format(required))
            all_ok = False
    
    return all_ok

def test_formal_validation_report():
    """Test formal validation report generation."""
    print('\n=== Formal Validation Report Test ===\n')
    
    import subprocess
    import tempfile
    
    report_script = 'scripts/ci/generate_formal_validation_report.py'
    if not os.path.exists(report_script):
        print('FAIL: Report generation script not found')
        return False
    
    with tempfile.TemporaryDirectory(prefix='mohawk-formal-') as tmp_dir:
        out_path = os.path.join(tmp_dir, 'formal_validation_report.json')
        
        # Run report generation
        result = subprocess.run(
            ['python3', report_script, '--output', out_path],
            capture_output=True,
            text=True
        )
        
        if result.returncode != 0:
            print('FAIL: Report generation failed')
            print('STDERR: {}'.format(result.stderr))
            return False
        
        if not os.path.exists(out_path):
            print('FAIL: Report file not created')
            return False
        
        print('PASS: Report generated ({} bytes)'.format(os.path.getsize(out_path)))
        
        # Validate report structure
        try:
            with open(out_path, 'r') as f:
                payload = json.load(f)
        except Exception as e:
            print('FAIL: Report JSON parse error: {}'.format(e))
            return False
        
        required_keys = [
            'schema_version',
            'toolchain_lock',
            'inputs',
            'input_merkle_root',
            'traceability',
            'lean_modules',
            'summary',
        ]
        
        missing = [k for k in required_keys if k not in payload]
        if missing:
            print('FAIL: Missing report keys: {}'.format(missing))
            return False
        
        print('PASS: All required report fields present')
        
        # Validate toolchain lock
        toolchain = payload.get('toolchain_lock', {})
        toolchain_fields = ['lean_toolchain', 'mathlib4_ref', 'go_version']
        missing_toolchain = [f for f in toolchain_fields if not toolchain.get(f)]
        if missing_toolchain:
            print('FAIL: Toolchain lock missing: {}'.format(missing_toolchain))
            return False
        
        print('PASS: Toolchain lock complete')
        return True

def test_merge_status():
    """Verify merge commit is valid."""
    print('\n=== Merge Commit Status ===\n')
    
    import subprocess
    
    # Check current commit
    result = subprocess.run(
        ['git', 'log', '--oneline', '-3'],
        cwd='Sovereign-Mohawk-Proto',
        capture_output=True,
        text=True
    )
    
    if result.returncode != 0:
        print('FAIL: Could not check git log')
        return False
    
    print('Recent commits:')
    for line in result.stdout.strip().split('\n'):
        print('  {}'.format(line))
    
    # Check for merge commit
    if 'Merge' in result.stdout:
        print('\nPASS: Merge commit detected')
        return True
    else:
        print('\nFAIL: No merge commit found')
        return False

def main():
    """Run all formal proof tests."""
    print('\n' + '='*60)
    print('FORMAL PROOF SYSTEM VALIDATION')
    print('='*60)
    
    results = {
        'Traceability Matrix': test_traceability_matrix(),
        'Lean Modules': test_lean_modules(),
        'Formal Validation Report': test_formal_validation_report(),
        'Merge Status': test_merge_status(),
    }
    
    print('\n' + '='*60)
    print('TEST RESULTS SUMMARY')
    print('='*60 + '\n')
    
    all_pass = True
    for test_name, passed in results.items():
        status = 'PASS' if passed else 'FAIL'
        print('{}: {}'.format(test_name, status))
        if not passed:
            all_pass = False
    
    print('\n' + '='*60)
    if all_pass:
        print('ALL FORMAL PROOF TESTS PASSED - PR READY TO MERGE')
    else:
        print('SOME TESTS FAILED - REVIEW REQUIRED')
    print('='*60 + '\n')
    
    return 0 if all_pass else 1

if __name__ == '__main__':
    exit(main())
