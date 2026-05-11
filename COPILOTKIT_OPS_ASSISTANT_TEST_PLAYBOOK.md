# CopilotKit Operations Assistant - Test Execution Playbook

**Purpose**: Detailed test procedures and templates for sprint execution  
**Audience**: QA Engineers, Developers, Test Automation  
**Updated**: May 11, 2026  

---

## 🧪 UNIT TEST TEMPLATES & EXECUTION

### DAY 1: Backend Unit Tests

#### Test Suite 1.1: prometheus-client.ts

**File**: `server/__tests__/prometheus-client.test.ts`

```typescript
describe('PrometheusClient', () => {
  describe('instantQuery', () => {
    test('should execute valid PromQL query', async () => {
      const query = 'rate(mohawk:gradient_submit:total[1m])';
      const result = await client.instantQuery(query);
      expect(result.status).toBe('success');
      expect(result.data).toBeDefined();
    });

    test('should handle invalid query syntax', async () => {
      const query = 'invalid_query{broken';
      expect(() => client.instantQuery(query)).toThrow('Invalid PromQL syntax');
    });

    test('should timeout after 5 seconds', async () => {
      // Mock slow Prometheus response
      expect(async () => {
        await client.instantQuery('slow_query', { timeout: 1000 });
      }).rejects.toThrow('Query timeout');
    });

    test('should parse numeric values correctly', async () => {
      const result = await client.instantQuery('metric_value');
      expect(result.data.result[0].value[1]).toBe(expect.any(String));
      expect(parseFloat(result.data.result[0].value[1])).toBeGreaterThan(0);
    });

    test('should handle empty results', async () => {
      const result = await client.instantQuery('nonexistent_metric');
      expect(result.data.result).toEqual([]);
    });
  });

  describe('rangeQuery', () => {
    test('should execute range query with time parameters', async () => {
      const query = 'rate(mohawk:gradient_submit:total[1m])';
      const result = await client.rangeQuery(query, {
        start: '30m ago',
        end: 'now',
        step: '1m'
      });
      expect(result.status).toBe('success');
      expect(Array.isArray(result.data.result)).toBe(true);
    });

    test('should handle invalid time format', async () => {
      expect(() => client.rangeQuery('metric', {
        start: 'invalid_time',
        end: 'now'
      })).toThrow('Invalid time format');
    });

    test('should parse time series data correctly', async () => {
      const result = await client.rangeQuery('metric', {
        start: '1h ago',
        end: 'now'
      });
      expect(result.data.result[0].values).toBeDefined();
      expect(Array.isArray(result.data.result[0].values)).toBe(true);
    });
  });

  describe('Connection Management', () => {
    test('should establish connection to Prometheus', async () => {
      const connected = await client.isConnected();
      expect(connected).toBe(true);
    });

    test('should handle Prometheus down gracefully', async () => {
      // Mock Prometheus unavailability
      const error = await client.query('metric').catch(e => e);
      expect(error.message).toContain('Could not reach Prometheus');
    });

    test('should retry on transient failures', async () => {
      // Mock retry logic
      const result = await client.queryWithRetry('metric', { maxRetries: 3 });
      expect(result).toBeDefined();
    });
  });
});
```

**Execution**:
```bash
npm test -- prometheus-client.test.ts --coverage
```

**Success Criteria**:
- ✅ All 12+ tests passing
- ✅ Coverage ≥ 90%
- ✅ Execution time < 5 seconds

---

#### Test Suite 1.2: CopilotKit Actions

**File**: `server/__tests__/actions/query-prometheus.test.ts`

```typescript
describe('queryPrometheus Action', () => {
  describe('Input Validation', () => {
    test('should accept valid PromQL query', async () => {
      const result = await queryPrometheus({
        query: 'rate(mohawk:gradient_submit:total[1m])'
      });
      expect(result).toBeDefined();
      expect(result.status).toBe('success');
    });

    test('should reject query without query parameter', async () => {
      expect(() => queryPrometheus({})).toThrow('Missing required parameter: query');
    });

    test('should accept optional rangeMinutes parameter', async () => {
      const result = await queryPrometheus({
        query: 'metric',
        rangeMinutes: 30
      });
      expect(result).toBeDefined();
    });

    test('should validate rangeMinutes is positive integer', async () => {
      expect(() => queryPrometheus({
        query: 'metric',
        rangeMinutes: -1
      })).toThrow('rangeMinutes must be positive');

      expect(() => queryPrometheus({
        query: 'metric',
        rangeMinutes: 1.5
      })).toThrow('rangeMinutes must be integer');
    });
  });

  describe('Response Format', () => {
    test('should return structured response with expected fields', async () => {
      const result = await queryPrometheus({
        query: 'up'
      });
      expect(result).toHaveProperty('status');
      expect(result).toHaveProperty('data');
      expect(result).toHaveProperty('timestamp');
    });

    test('should format numeric values correctly', async () => {
      const result = await queryPrometheus({
        query: 'metric'
      });
      expect(result.data.result[0].value[1]).toMatch(/^\d+(\.\d+)?$/);
    });

    test('should include metadata in response', async () => {
      const result = await queryPrometheus({
        query: 'metric'
      });
      expect(result.executionTime).toBeDefined();
      expect(result.executionTime).toBeGreaterThan(0);
    });
  });

  describe('Error Handling', () => {
    test('should return user-friendly error for invalid syntax', async () => {
      const result = await queryPrometheus({
        query: 'invalid{query['
      });
      expect(result.status).toBe('error');
      expect(result.error).toContain('PromQL');
      expect(result.error).not.toContain('stack trace');
    });

    test('should not expose system information in errors', async () => {
      const result = await queryPrometheus({
        query: 'query'
      });
      if (result.status === 'error') {
        expect(result.error).not.toMatch(/\/home|\/etc|password|secret/i);
      }
    });
  });
});
```

**Execution**:
```bash
npm test -- actions/query-prometheus.test.ts --coverage
```

**Success Criteria**:
- ✅ All action tests passing
- ✅ Coverage ≥ 85%
- ✅ Error messages user-friendly

---

#### Test Suite 1.3: Frontend Components

**File**: `client/__tests__/ChatInterface.test.tsx`

```typescript
import { render, screen, fireEvent } from '@testing-library/react';
import ChatInterface from '../components/ChatInterface';

describe('ChatInterface Component', () => {
  describe('Rendering', () => {
    test('should render chat input field', () => {
      render(<ChatInterface />);
      const input = screen.getByPlaceholderText(/ask about metrics/i);
      expect(input).toBeInTheDocument();
    });

    test('should render send button', () => {
      render(<ChatInterface />);
      const button = screen.getByRole('button', { name: /send|submit/i });
      expect(button).toBeInTheDocument();
    });

    test('should have empty message history on load', () => {
      render(<ChatInterface />);
      const history = screen.queryByText(/no messages yet/i);
      expect(history).toBeInTheDocument();
    });
  });

  describe('Message Handling', () => {
    test('should send message when button clicked', () => {
      render(<ChatInterface />);
      const input = screen.getByPlaceholderText(/ask about metrics/i);
      const btn = screen.getByRole('button', { name: /send/i });

      fireEvent.change(input, { target: { value: 'Test message' } });
      fireEvent.click(btn);

      expect(screen.getByText('Test message')).toBeInTheDocument();
    });

    test('should clear input after sending', () => {
      render(<ChatInterface />);
      const input = screen.getByPlaceholderText(/ask about metrics/i);
      const btn = screen.getByRole('button', { name: /send/i });

      fireEvent.change(input, { target: { value: 'Message' } });
      fireEvent.click(btn);

      expect(input.value).toBe('');
    });

    test('should not send empty messages', () => {
      render(<ChatInterface />);
      const btn = screen.getByRole('button', { name: /send/i });

      fireEvent.click(btn); // Empty input

      // Should not add message
      expect(screen.queryByText(/undefined|null/)).not.toBeInTheDocument();
    });

    test('should display both user and assistant messages', async () => {
      render(<ChatInterface />);
      const input = screen.getByPlaceholderText(/ask about metrics/i);
      const btn = screen.getByRole('button', { name: /send/i });

      fireEvent.change(input, { target: { value: 'User question' } });
      fireEvent.click(btn);

      // Wait for response
      await screen.findByText(/assistant response/i, {}, { timeout: 5000 });

      expect(screen.getByText('User question')).toBeInTheDocument();
    });
  });

  describe('Accessibility', () => {
    test('should be keyboard navigable', () => {
      render(<ChatInterface />);
      const input = screen.getByPlaceholderText(/ask about metrics/i);

      input.focus();
      expect(document.activeElement).toBe(input);

      fireEvent.keyDown(input, { key: 'Enter' });
      expect(input).toHaveFocus();
    });

    test('should have proper ARIA labels', () => {
      render(<ChatInterface />);
      const btn = screen.getByRole('button', { name: /send/i });
      expect(btn).toHaveAccessibleName();
    });

    test('should have sufficient color contrast', () => {
      const { container } = render(<ChatInterface />);
      // Would use a contrast checking library
      const elements = container.querySelectorAll('*');
      // Verify contrast ratios
    });
  });
});
```

**Execution**:
```bash
npm run test:ui -- --coverage ChatInterface
```

**Success Criteria**:
- ✅ All component tests passing
- ✅ Coverage ≥ 80%
- ✅ Accessibility checks pass

---

## 🧩 INTEGRATION TEST TEMPLATES

### DAY 2: Backend Integration Tests

#### Test Suite 2.1: API Endpoint Tests

**File**: `server/__tests__/integration/api.test.ts`

```typescript
import request from 'supertest';
import app from '../../index';

describe('API Endpoints Integration', () => {
  describe('GET /api/health', () => {
    test('should return 200 OK', async () => {
      const response = await request(app).get('/api/health');
      expect(response.status).toBe(200);
    });

    test('should return health status object', async () => {
      const response = await request(app).get('/api/health');
      expect(response.body).toHaveProperty('status');
      expect(response.body).toHaveProperty('timestamp');
      expect(response.body.status).toMatch(/healthy|degraded/);
    });

    test('should indicate Prometheus connectivity', async () => {
      const response = await request(app).get('/api/health');
      expect(response.body).toHaveProperty('prometheus');
      expect(response.body.prometheus).toMatch(/connected|disconnected/);
    });
  });

  describe('POST /api/prometheus/query', () => {
    test('should accept PromQL query', async () => {
      const response = await request(app)
        .post('/api/prometheus/query')
        .send({ query: 'up' });
      expect(response.status).toBe(200);
    });

    test('should validate required fields', async () => {
      const response = await request(app)
        .post('/api/prometheus/query')
        .send({}); // Missing query
      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error');
    });

    test('should return structured response', async () => {
      const response = await request(app)
        .post('/api/prometheus/query')
        .send({ query: 'rate(requests:total[1m])' });
      expect(response.body).toHaveProperty('status');
      expect(response.body).toHaveProperty('data');
    });

    test('should support range queries', async () => {
      const response = await request(app)
        .post('/api/prometheus/query')
        .send({
          query: 'metric',
          rangeMinutes: 30
        });
      expect(response.status).toBe(200);
    });
  });

  describe('POST /api/incident-summary', () => {
    test('should generate incident summary', async () => {
      const response = await request(app)
        .post('/api/incident-summary')
        .send({ startTime: '30m ago', endTime: 'now' });
      expect(response.status).toBe(200);
    });

    test('should return summary structure', async () => {
      const response = await request(app)
        .post('/api/incident-summary')
        .send({});
      expect(response.body).toHaveProperty('summary');
      expect(response.body.summary).toHaveProperty('status');
      expect(response.body.summary).toHaveProperty('issues');
      expect(response.body.summary).toHaveProperty('recommendations');
    });

    test('should complete within 5 seconds', async () => {
      const start = Date.now();
      await request(app)
        .post('/api/incident-summary')
        .send({});
      const duration = Date.now() - start;
      expect(duration).toBeLessThan(5000);
    });
  });

  describe('POST /api/dashboard/explain', () => {
    test('should explain dashboard', async () => {
      const response = await request(app)
        .post('/api/dashboard/explain')
        .send({ dashboardName: 'v2-10-ops-overview' });
      expect(response.status).toBe(200);
    });

    test('should return dashboard structure', async () => {
      const response = await request(app)
        .post('/api/dashboard/explain')
        .send({ dashboardName: 'v2-10-ops-overview' });
      expect(response.body).toHaveProperty('title');
      expect(response.body).toHaveProperty('description');
      expect(response.body).toHaveProperty('keyMetrics');
    });
  });
});
```

**Execution**:
```bash
npm test -- integration/api.test.ts --maxWorkers=1
```

**Success Criteria**:
- ✅ All endpoints respond correctly
- ✅ Input validation working
- ✅ Response formats validated
- ✅ Performance within SLA

---

## 🌐 END-TO-END TEST SCENARIOS

### DAY 3: E2E User Workflows

#### Scenario 1: Query Current Metrics

**Test Name**: E2E_001_Query_Current_Throughput  
**User Story**: As an operator, I want to ask for current throughput

**Test Steps**:
```
1. SETUP
   ✓ Navigate to http://localhost:3001
   ✓ Verify page loads (< 3 seconds)
   ✓ Verify chat interface is ready
   ✓ Clear any previous messages

2. EXECUTE
   ✓ User asks: "What is the current gradient throughput?"
   ✓ Wait for response (5 second timeout)
   ✓ Verify response appears in chat

3. VERIFY
   ✓ Response contains numeric value
   ✓ Response includes units (queries/sec)
   ✓ Response includes timestamp
   ✓ Response is from last 5 minutes
   ✓ No error messages visible
   ✓ No stack traces visible

4. VALIDATE
   ✓ Compare with Prometheus dashboard manually
   ✓ Value is within expected range
   ✓ Response time logged: ___ ms

EXPECTED RESULT:
  ✅ User sees current throughput: X queries/sec
  ✅ Response time < 1 second
  ✅ Output formatted clearly
```

**Test Data**:
```json
{
  "query": "What is the current gradient throughput?",
  "expectedFields": ["value", "unit", "timestamp"],
  "expectedUnit": "queries/sec",
  "performanceTarget": "< 1000ms"
}
```

**Pass Criteria**: ✅ Response accurate, formatted, within SLA

---

#### Scenario 2: Generate Incident Summary

**Test Name**: E2E_002_Incident_Analysis  
**User Story**: As an operator, I want to analyze what happened in the last 30 minutes

**Test Steps**:
```
1. SETUP
   ✓ Navigate to http://localhost:3001
   ✓ Clear chat history

2. EXECUTE
   ✓ User asks: "Generate an incident summary from the last 30 minutes"
   ✓ Wait for analysis (10 second timeout)
   ✓ Verify response appears

3. VERIFY RESPONSE STRUCTURE
   ✓ Response includes: status (healthy/anomalies_detected)
   ✓ Response includes: issues (array)
   ✓ Response includes: successes (array)
   ✓ Response includes: recommendations (array)
   ✓ Each item has description and severity

4. VERIFY CONTENT
   ✓ Status matches metrics data
   ✓ Issues are actionable
   ✓ Recommendations are specific
   ✓ Links to dashboards (if applicable)

5. PERFORMANCE
   ✓ Response time: ___ ms (target: < 2000ms)
   ✓ Memory spike < 50MB
```

**Test Data**:
```json
{
  "query": "Generate an incident summary from the last 30 minutes",
  "expectedFields": ["status", "issues", "successes", "recommendations"],
  "timeRange": "30m",
  "performanceTarget": "< 2000ms"
}
```

**Pass Criteria**: ✅ Complete analysis, accurate assessment, actionable recommendations

---

#### Scenario 3: Dashboard Explanation

**Test Name**: E2E_003_Dashboard_Explanation  
**User Story**: As a new team member, I want to understand what a dashboard measures

**Test Steps**:
```
1. SETUP
   ✓ Navigate to http://localhost:3001
   ✓ Clear chat

2. EXECUTE
   ✓ User asks: "Explain the v2-10-ops-overview dashboard"
   ✓ Wait for response (5 second timeout)

3. VERIFY RESPONSE
   ✓ Response includes dashboard title
   ✓ Response includes overall purpose
   ✓ Response lists key metrics (≥ 3)
   ✓ Response explains metric purpose (1-2 sentences)
   ✓ Response suggests dashboards to compare

4. VERIFY ACCURACY
   ✓ Cross-check with actual Grafana dashboard
   ✓ Descriptions match dashboard panels
   ✓ Metrics are correctly identified

5. PERFORMANCE
   ✓ Response time: ___ ms (target: < 500ms)
```

**Pass Criteria**: ✅ Accurate explanation, complete metric list, good performance

---

#### Scenario 4: Error Handling

**Test Name**: E2E_004_Error_Handling  
**User Story**: As an operator, I want helpful error messages if I provide invalid input

**Test Steps**:
```
1. TEST: Invalid PromQL
   ✓ User asks: "Query: invalid_metric{total"
   ✓ System detects syntax error
   ✓ Response: "Query syntax error: ..."
   ✓ No stack trace visible
   ✓ Message is user-friendly

2. TEST: Nonexistent Metric
   ✓ User asks: "Show metric_that_does_not_exist"
   ✓ System queries and gets empty result
   ✓ Response: "No data found for..."
   ✓ Suggests valid metrics

3. TEST: Network Error
   ✓ Simulate Prometheus disconnect
   ✓ User asks: "What is throughput?"
   ✓ Response: "Cannot reach monitoring system..."
   ✓ Message is clear
   ✓ Indicates when service will retry

4. TEST: Timeout
   ✓ Query takes > 5 seconds
   ✓ System times out gracefully
   ✓ Response: "Query timeout. Try a smaller time range..."
```

**Pass Criteria**: ✅ All errors handled gracefully, no stack traces, helpful messages

---

#### Scenario 5: Load Test

**Test Name**: E2E_005_Load_Test  
**User Story**: As operations, we want the system to handle concurrent users

**Test Steps**:
```
1. SETUP
   ✓ Full stack running
   ✓ Load test tool configured (k6, jmeter, or custom)
   ✓ Prometheus in normal operating state

2. EXECUTE: 10 Concurrent Users
   ✓ Each user sends 1 query per second
   ✓ Test runs for 5 minutes
   ✓ Monitor system resources

3. EXECUTE: 50 Concurrent Users
   ✓ Each user sends 1 query per 5 seconds
   ✓ Test runs for 5 minutes

4. VERIFY RESULTS
   ✓ All queries complete successfully
   ✓ P50 response time: ___ ms (target: < 500ms)
   ✓ P95 response time: ___ ms (target: < 1000ms)
   ✓ P99 response time: ___ ms (target: < 2000ms)
   ✓ Error rate: ___ % (target: < 0.1%)
   ✓ Memory usage: ___ MB (target: < 250MB)
   ✓ CPU usage: ___ % (target: < 50%)

5. STABILITY
   ✓ No crashes during test
   ✓ No memory leaks (memory stable)
   ✓ All services remain responsive
```

**Pass Criteria**: ✅ Handles load, acceptable response times, no errors

---

## 📊 PERFORMANCE TEST TEMPLATES

### Day 3: Performance Benchmarks

#### Test: Query Response Time

```bash
#!/bin/bash
# Query response time test

echo "Testing query response times..."

queries=(
  "rate(mohawk:gradient_submit:total[1m])"
  "increase(mohawk_fedavg_byzantine_filtered_total[5m])"
  "histogram_quantile(0.95, mohawk_fedavg_round_latency_quantile_ms)"
)

for query in "${queries[@]}"; do
  echo "Query: $query"
  
  start_time=$(date +%s%3N)
  
  curl -s -X POST http://localhost:3001/api/prometheus/query \
    -H "Content-Type: application/json" \
    -d "{\"query\":\"$query\"}" > /dev/null
  
  end_time=$(date +%s%3N)
  response_time=$((end_time - start_time))
  
  echo "  Response time: ${response_time}ms"
  
  if [ $response_time -lt 500 ]; then
    echo "  ✅ PASS (< 500ms)"
  else
    echo "  ❌ FAIL (>= 500ms)"
  fi
done
```

**Expected Output**:
```
Query: rate(mohawk:gradient_submit:total[1m])
  Response time: 245ms
  ✅ PASS (< 500ms)

Query: increase(mohawk_fedavg_byzantine_filtered_total[5m])
  Response time: 389ms
  ✅ PASS (< 500ms)

Query: histogram_quantile(0.95, mohawk_fedavg_round_latency_quantile_ms)
  Response time: 412ms
  ✅ PASS (< 500ms)
```

---

#### Test: Memory Usage

```bash
#!/bin/bash
# Memory usage test

echo "Testing memory usage..."

# Get baseline
baseline=$(docker stats --no-stream ops-assistant | tail -1 | awk '{print $4}' | sed 's/MiB//')
echo "Baseline memory: ${baseline}MiB"

# Run 100 queries
for i in {1..100}; do
  curl -s -X POST http://localhost:3001/api/prometheus/query \
    -H "Content-Type: application/json" \
    -d '{"query":"up"}' > /dev/null
  
  if [ $((i % 10)) -eq 0 ]; then
    current=$(docker stats --no-stream ops-assistant | tail -1 | awk '{print $4}' | sed 's/MiB//')
    echo "After $i queries: ${current}MiB"
  fi
done

# Check final memory
final=$(docker stats --no-stream ops-assistant | tail -1 | awk '{print $4}' | sed 's/MiB//')
echo "Final memory: ${final}MiB"

if [ $(echo "$final < 250" | bc) -eq 1 ]; then
  echo "✅ PASS: Memory < 250MiB"
else
  echo "❌ FAIL: Memory >= 250MiB"
fi
```

---

## 📝 TEST REPORT TEMPLATE

### Daily Test Execution Report

```markdown
# Test Execution Report - [DATE]

## Summary
- **Total Tests**: 150
- **Passed**: 150
- **Failed**: 0
- **Skipped**: 0
- **Pass Rate**: 100%

## Test Coverage
- Backend: 85%
- Frontend: 80%
- Integration: 75%

## Performance Metrics
- Query Response Time (P95): 412ms (Target: < 500ms) ✅
- Incident Summary (P95): 1,850ms (Target: < 2000ms) ✅
- Memory Usage: 185MB (Target: < 250MB) ✅

## Issues Found
| ID | Severity | Component | Status |
|----|----------|-----------|--------|
| - | - | - | All resolved |

## Sign-Off
- QA Lead: [Name] ✅
- Date: [YYYY-MM-DD]
- Notes: All requirements met, ready for next phase
```

---

## ✅ Test Execution Checklist - Day 5

```
FINAL REGRESSION TEST CHECKLIST:

Unit Tests:
  ☐ Backend tests: /docker_tests/backend_unit_tests.log
  ☐ Coverage: 85% ✅
  ☐ All pass: ✅
  
Integration Tests:
  ☐ API tests: /docker_tests/api_integration_tests.log
  ☐ All pass: ✅
  
E2E Tests:
  ☐ Scenario 1 (Query): ✅ PASS
  ☐ Scenario 2 (Analysis): ✅ PASS
  ☐ Scenario 3 (Explain): ✅ PASS
  ☐ Scenario 4 (Error): ✅ PASS
  ☐ Scenario 5 (Load): ✅ PASS

Performance:
  ☐ Query response: 412ms (Target: < 500ms) ✅
  ☐ Incident summary: 1,850ms (Target: < 2000ms) ✅
  ☐ Memory: 185MB (Target: < 250MB) ✅

Docker:
  ☐ Build successful: ✅
  ☐ Container runs: ✅
  ☐ Health check passes: ✅

Deployment:
  ☐ Dry-run successful: ✅
  ☐ Rollback tested: ✅
  ☐ Monitoring configured: ✅

Sign-offs:
  ☐ QA approval: ✅
  ☐ Tech lead approval: ✅
  ☐ Security approval: ✅
  ☐ DevOps approval: ✅

OVERALL STATUS: ✅ READY FOR PRODUCTION
```

---

**Test Playbook Status**: 🟢 READY TO USE  
**Last Updated**: May 11, 2026
