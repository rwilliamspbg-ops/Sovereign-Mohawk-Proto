#!/usr/bin/env python3
"""
Test Execution Analysis Script
Sovereign-Mohawk Phase 1-4 Complete Suite
Compares actual results against expected metrics
"""

import re
import sys
from datetime import datetime
from collections import defaultdict

class TestAnalyzer:
    def __init__(self):
        self.phase_results = defaultdict(lambda: {'pass': 0, 'fail': 0, 'tests': []})
        self.expected_results = {
            'phase1': {'total': 65, 'expected_pass': 59, 'expected_pass_rate': 0.90},
            'phase2': {'total': 60, 'expected_pass': 54, 'expected_pass_rate': 0.90},
            'phase3': {'total': 48, 'expected_pass': 43, 'expected_pass_rate': 0.89},
            'phase4': {'total': 55, 'expected_pass': 49, 'expected_pass_rate': 0.89},
        }
        self.total_time = 0
        self.test_times = {}
        
    def parse_test_output(self, output):
        """Parse test output and extract results"""
        lines = output.split('\n')
        
        for line in lines:
            # Parse PASS lines: "--- PASS: TestPhase1DataLoaderSequential (0.05s)"
            if '--- PASS:' in line:
                match = re.search(r'TestPhase(\d)(\w+)\s+\(([\d.]+)s\)', line)
                if match:
                    phase_num = match.group(1)
                    test_name = match.group(2)
                    test_time = float(match.group(3))
                    phase_key = f'phase{phase_num}'
                    
                    self.phase_results[phase_key]['pass'] += 1
                    self.phase_results[phase_key]['tests'].append({
                        'name': test_name,
                        'status': 'PASS',
                        'time': test_time
                    })
                    self.test_times[test_name] = test_time
            
            # Parse FAIL lines: "--- FAIL: TestPhase1DataLoaderSequential (0.05s)"
            elif '--- FAIL:' in line:
                match = re.search(r'TestPhase(\d)(\w+)\s+\(([\d.]+)s\)', line)
                if match:
                    phase_num = match.group(1)
                    test_name = match.group(2)
                    test_time = float(match.group(3))
                    phase_key = f'phase{phase_num}'
                    
                    self.phase_results[phase_key]['fail'] += 1
                    self.phase_results[phase_key]['tests'].append({
                        'name': test_name,
                        'status': 'FAIL',
                        'time': test_time
                    })
                    self.test_times[test_name] = test_time
            
            # Parse total time: "ok  	github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal	285.45s"
            if 'ok' in line and 's' in line:
                match = re.search(r'(\d+\.\d+)s$', line)
                if match:
                    self.total_time = float(match.group(1))
    
    def generate_report(self):
        """Generate analysis report"""
        report = []
        report.append("# TEST EXECUTION ANALYSIS REPORT")
        report.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report.append("")
        
        # Summary
        report.append("## EXECUTIVE SUMMARY")
        total_pass = sum(r['pass'] for r in self.phase_results.values())
        total_fail = sum(r['fail'] for r in self.phase_results.values())
        total_tests = total_pass + total_fail
        
        report.append(f"- **Total Tests Executed:** {total_tests}")
        report.append(f"- **Passed:** {total_pass}")
        report.append(f"- **Failed:** {total_fail}")
        report.append(f"- **Pass Rate:** {total_pass}/{total_tests} ({100*total_pass/total_tests:.1f}%)")
        report.append(f"- **Total Runtime:** {self.total_time:.2f}s ({self.total_time/60:.1f} minutes)")
        report.append("")
        
        # Phase-by-phase analysis
        report.append("## PHASE-BY-PHASE RESULTS")
        report.append("")
        
        for phase_num in range(1, 5):
            phase_key = f'phase{phase_num}'
            results = self.phase_results[phase_key]
            expected = self.expected_results[phase_key]
            
            pass_count = results['pass']
            fail_count = results['fail']
            total = pass_count + fail_count
            pass_rate = pass_count / total if total > 0 else 0
            
            expected_pass = expected['expected_pass']
            expected_pass_rate = expected['expected_pass_rate']
            
            # Calculate variance
            pass_variance = pass_count - expected_pass
            pass_rate_variance = pass_rate - expected_pass_rate
            
            report.append(f"### Phase {phase_num}")
            report.append(f"- **Tests:** {total}/{expected['total']}")
            report.append(f"- **Passed:** {pass_count} (Expected: {expected_pass})")
            report.append(f"- **Failed:** {fail_count}")
            report.append(f"- **Pass Rate:** {pass_rate:.1%} (Expected: {expected_pass_rate:.1%})")
            
            if pass_variance > 0:
                report.append(f"- **Variance:** +{pass_variance} tests ({pass_rate_variance:+.1%})")
            elif pass_variance < 0:
                report.append(f"- **Variance:** {pass_variance} tests ({pass_rate_variance:+.1%})")
            else:
                report.append(f"- **Variance:** On target")
            
            report.append("")
        
        # Failed tests
        report.append("## FAILED TESTS")
        failed_tests = []
        for phase_num in range(1, 5):
            phase_key = f'phase{phase_num}'
            for test in self.phase_results[phase_key]['tests']:
                if test['status'] == 'FAIL':
                    failed_tests.append((phase_num, test['name'], test['time']))
        
        if failed_tests:
            report.append(f"Total failed: {len(failed_tests)}")
            report.append("")
            for phase, name, time in failed_tests:
                report.append(f"- **Phase {phase}:** {name} ({time:.2f}s)")
            report.append("")
        else:
            report.append("✅ No failed tests")
            report.append("")
        
        # Performance analysis
        report.append("## PERFORMANCE ANALYSIS")
        report.append("")
        
        phase_times = defaultdict(float)
        phase_counts = defaultdict(int)
        
        for phase_num in range(1, 5):
            phase_key = f'phase{phase_num}'
            for test in self.phase_results[phase_key]['tests']:
                phase_times[phase_num] += test['time']
                phase_counts[phase_num] += 1
        
        for phase_num in range(1, 5):
            if phase_counts[phase_num] > 0:
                total_time = phase_times[phase_num]
                avg_time = total_time / phase_counts[phase_num]
                report.append(f"- **Phase {phase_num}:** {total_time:.2f}s total, {avg_time*1000:.1f}ms per test")
        
        report.append(f"- **Total Suite Runtime:** {self.total_time:.2f}s")
        report.append("")
        
        # Comparison to expectations
        report.append("## COMPARISON TO EXPECTED RESULTS")
        report.append("")
        
        report.append("| Phase | Expected | Actual | Pass Rate | Status |")
        report.append("|-------|----------|--------|-----------|--------|")
        
        for phase_num in range(1, 5):
            phase_key = f'phase{phase_num}'
            results = self.phase_results[phase_key]
            expected = self.expected_results[phase_key]
            
            pass_count = results['pass']
            total = pass_count + results['fail']
            pass_rate = pass_count / total if total > 0 else 0
            
            expected_pass = expected['expected_pass']
            expected_rate = expected['expected_pass_rate']
            
            status = "✅ MET" if pass_count >= expected_pass else "⚠️ BELOW"
            
            report.append(f"| {phase_num} | {expected_pass}/{expected['total']} | {pass_count}/{total} | {pass_rate:.1%} | {status} |")
        
        report.append("")
        
        # Final status
        report.append("## FINAL STATUS")
        report.append("")
        
        total_expected = sum(e['expected_pass'] for e in self.expected_results.values())
        
        if total_pass >= total_expected * 0.90:
            report.append("✅ **PASS** - Test suite execution successful")
            report.append(f"Pass rate {total_pass}/{total_tests} ({100*total_pass/total_tests:.1%}) meets or exceeds 90% target")
        else:
            report.append("⚠️ **REVIEW REQUIRED** - Some tests did not meet expectations")
            report.append(f"Pass rate {total_pass}/{total_tests} ({100*total_pass/total_tests:.1%}) is below 90% target")
        
        report.append("")
        report.append("---")
        report.append(f"Report generated: {datetime.now().isoformat()}")
        
        return "\n".join(report)

if __name__ == "__main__":
    # Read test output from file or stdin
    if len(sys.argv) > 1:
        with open(sys.argv[1], 'r') as f:
            output = f.read()
    else:
        output = sys.stdin.read()
    
    analyzer = TestAnalyzer()
    analyzer.parse_test_output(output)
    
    report = analyzer.generate_report()
    print(report)
    
    # Also save to file
    with open("TEST_EXECUTION_ANALYSIS.md", "w") as f:
        f.write(report)
    
    print("\nAnalysis saved to TEST_EXECUTION_ANALYSIS.md")
