# CopilotKit Operations Assistant - Sprint Quick Reference

**Quick Links & Commands for Daily Execution**

---

## 🚀 Quick Start Commands

```bash
# Navigate to project
cd /workspaces/Sovereign-Mohawk-Proto/web/ops-assistant

# Install dependencies
npm install

# Day 1: Code Validation & Unit Tests
npm run lint                    # Check code style
npm run type-check            # TypeScript compilation check
npm run build                 # Production build
npm test -- --coverage        # Run unit tests with coverage

# Day 2: Integration & Docker Tests
npm run test:integration      # Run integration tests
docker build -t ops-assistant:latest .
docker run -p 3001:3000 ops-assistant:latest
docker-compose up -d

# Day 3: E2E Testing
npm run test:e2e              # Run end-to-end tests
npm run test:performance      # Performance tests

# Day 4: Security & Docs
npm audit                     # Security scan
npm audit fix                 # Fix vulnerabilities

# Day 5: Final Release
npm run build                 # Final build
git tag -a v1.0.0-ops-assistant -m "Release"
docker build -t ops-assistant:v1.0.0 .
```

---

## 📋 Daily Checklist Templates

### DAY 1: Foundation & Unit Tests (9:00-18:00)

**Morning: 9:00-13:00**
```
☐ 1.1 Code Audit
  ☐ npm run lint
  ☐ npm run type-check
  ☐ npm run build
  ☐ Fix any errors
  ☐ Document compile status

☐ 1.2 Backend Unit Tests
  ☐ Create server/__tests__/ directory
  ☐ Write prometheus-client.ts tests
  ☐ Write actions/*.ts tests
  ☐ npm test -- --coverage
  ☐ Verify coverage ≥ 85%
  ☐ Document: Test summary.txt
```

**Afternoon: 14:00-18:00**
```
☐ 1.3 Frontend Unit Tests
  ☐ Create client/__tests__/ directory
  ☐ Write component tests
  ☐ npm run test:ui -- --coverage
  ☐ Verify coverage ≥ 80%

☐ 1.4 Dependency Scan
  ☐ npm audit --production
  ☐ npm audit fix
  ☐ npm list --depth=0
  ☐ Document: Security_Audit_Day1.txt

**End of Day 1:**
  ✅ Zero compile errors
  ✅ Backend coverage ≥ 85%
  ✅ Frontend coverage ≥ 80%
  ✅ Security scan done
```

---

### DAY 2: Integration & API Tests (9:00-18:00)

**Morning: 9:00-13:00**
```
☐ 2.1 Integration Tests
  ☐ Create server/__tests__/integration/
  ☐ Test Prometheus connectivity
  ☐ Test multi-action flows
  ☐ npm test -- integration --coverage
  ☐ Document: Integration_Test_Report.txt

☐ 2.2 API Endpoint Tests
  ☐ Test GET /api/health
  ☐ Test POST /api/prometheus/query
  ☐ Test POST /api/incident-summary
  ☐ Test POST /api/dashboard/explain
  ☐ Document: API_Test_Results.txt
```

**Afternoon: 14:00-18:00**
```
☐ 2.3 Docker Build & Test
  ☐ docker build -t ops-assistant:latest .
  ☐ docker inspect ops-assistant:latest
  ☐ Check image size (target: <350MB)
  ☐ docker run -p 3001:3000 ops-assistant:latest
  ☐ curl http://localhost:3001/api/health
  ☐ Document: Docker_Test_Results.txt

☐ 2.4 docker-compose Test
  ☐ docker-compose up -d
  ☐ Wait for all services to start
  ☐ Verify ops-assistant is healthy
  ☐ Test Prometheus connectivity
  ☐ docker-compose logs ops-assistant
  ☐ Document: Compose_Test_Results.txt

**End of Day 2:**
  ✅ Integration tests passing
  ✅ API endpoints working
  ✅ Docker image builds (< 350MB)
  ✅ docker-compose stack healthy
```

---

### DAY 3: End-to-End Testing (9:00-18:00)

**Morning: 9:00-13:00**
```
☐ 3.1 E2E Scenario Testing
  ☐ Start full stack: docker-compose up -d
  ☐ Scenario 1: Query metrics
    ☐ Open http://localhost:3001
    ☐ Ask: "What is current throughput?"
    ☐ Verify response in chat
    ☐ Record: Response OK ✅ / Failed ❌
  
  ☐ Scenario 2: Incident summary
    ☐ Ask: "Generate incident summary last 30m"
    ☐ Verify analysis completes
    ☐ Record: Response OK ✅ / Failed ❌
  
  ☐ Scenario 3: Dashboard explain
    ☐ Ask: "Explain v2-10-ops-overview"
    ☐ Verify description returned
    ☐ Record: Response OK ✅ / Failed ❌
  
  ☐ Scenario 4: Error handling
    ☐ Ask: "invalid_query{broken}"
    ☐ Verify error message (no stack trace)
    ☐ Record: Response OK ✅ / Failed ❌
  
  ☐ Scenario 5: Load test
    ☐ Launch 10 concurrent users tool
    ☐ Verify all complete
    ☐ Record: All passed ✅ / Some failed ❌
  
  ☐ Document: E2E_Test_Report.txt
```

**Afternoon: 14:00-18:00**
```
☐ 3.2 Frontend Component Tests
  ☐ Test ChatInterface rendering
  ☐ Test HealthStatus component
  ☐ Test message input/output
  ☐ Document: Component_Test_Results.txt

☐ 3.3 Performance Testing
  ☐ Measure: Single query response time ___ ms (target: <500ms)
  ☐ Measure: Incident summary ___ ms (target: <2000ms)
  ☐ Measure: Memory at startup ___ MB (target: <150MB)
  ☐ Measure: Memory after 100 queries ___ MB (target: <250MB)
  ☐ Measure: CPU idle ___ % (target: <1%)
  ☐ Measure: CPU during query ___ % (target: <30%)
  ☐ Document: Performance_Metrics.txt

☐ 3.4 Prometheus Validation
  ☐ Verify all metrics queryable
  ☐ Test throughput metric
  ☐ Test failure rate metric
  ☐ Test latency metric
  ☐ Test Byzantine metric
  ☐ Document: Prometheus_Validation.txt

☐ 3.5 CopilotKit Action Tests
  ☐ Test queryPrometheus action
  ☐ Test generateIncidentSummary action
  ☐ Test explainDashboard action
  ☐ Document: Action_Test_Results.txt

**End of Day 3:**
  ✅ All 5 E2E scenarios working
  ✅ Performance metrics captured
  ✅ All metrics accessible
  ✅ All actions responding
```

---

### DAY 4: Security & Documentation (9:00-18:00)

**Morning: 9:00-13:00**
```
☐ 4.1 Security Audit
  ☐ npm audit --production
  ☐ Check for hardcoded credentials: grep -r "password" .
  ☐ Check for secrets in git: git log -p | grep -i "secret"
  ☐ Review CORS configuration
  ☐ Verify input validation
  ☐ Document: Security_Audit_Report.txt

☐ 4.2 Documentation Review
  ☐ Verify implementation doc (COPILOTKIT_OPS_ASSISTANT_IMPLEMENTATION.md)
  ☐ Verify architecture doc (COPILOTKIT_OPS_ASSISTANT_ARCHITECTURE.md)
  ☐ Check all examples work
  ☐ Update if needed

☐ 4.3 Create DEPLOYMENT.md
  ☐ Prerequisites section
  ☐ Deployment steps
  ☐ Verification steps
  ☐ Rollback procedure

☐ 4.4 Create TROUBLESHOOTING.md
  ☐ Common issues
  ☐ Solutions
  ☐ Debug procedures
```

**Afternoon: 14:00-18:00**
```
☐ 4.5 Configuration Validation
  ☐ Verify .env.example complete
  ☐ Verify docker-compose.yml valid
  ☐ Verify Dockerfile optimized
  ☐ Verify tsconfig.json correct
  ☐ Document: Config_Validation.txt

☐ 4.6 Compliance Check
  ☐ ESLint rules: ✅ Pass
  ☐ TypeScript strict: ✅ Pass
  ☐ No console.log in prod code: ✅ Pass
  ☐ Naming conventions: ✅ Pass
  ☐ Document: Compliance_Checklist.txt

☐ 4.7 Logging & Monitoring
  ☐ Review logging points
  ☐ Verify no secrets logged
  ☐ Test /api/health endpoint
  ☐ Setup alerting (if applicable)
  ☐ Document: Monitoring_Setup.txt

☐ 4.8 Release Notes
  ☐ Update CHANGELOG.md
  ☐ Create release notes
  ☐ List new features
  ☐ List bug fixes
  ☐ Document contributors

**End of Day 4:**
  ✅ Security audit passed
  ✅ All documentation complete
  ✅ Configuration validated
  ✅ Compliance verified
  ✅ Release notes ready
```

---

### DAY 5: Testing & Deployment (9:00-18:00)

**Morning: 9:00-13:00**
```
☐ 5.1 Regression Testing
  ☐ npm test -- --coverage
  ☐ Backend tests: ___ pass, ___ fail
  ☐ Frontend tests: ___ pass, ___ fail
  ☐ Integration tests: ___ pass, ___ fail
  ☐ Document: Regression_Test_Report.txt

☐ 5.2 Production Dry-Run
  ☐ Clean build environment:
    rm -rf node_modules dist
    npm install
    npm run build
  ☐ Build Docker image:
    docker build -t ops-assistant:final .
  ☐ Run container:
    docker run -p 3001:3000 ops-assistant:final
  ☐ Verify health:
    curl http://localhost:3001/api/health
  ☐ Test functionality
  ☐ Document: Deployment_Dry_Run.txt
```

**Afternoon: 14:00-18:00**
```
☐ 5.3 Production Configuration
  ☐ Verify PROMETHEUS_URL set
  ☐ Verify NODE_ENV=production
  ☐ Verify PORT correct (3000)
  ☐ Verify no dev config in prod

☐ 5.4 Stakeholder Testing
  ☐ Demo Feature 1: Query metrics
  ☐ Demo Feature 2: Incident summary
  ☐ Demo Feature 3: Dashboard explain
  ☐ Demo Feature 4: Error handling
  ☐ Collect sign-off: ✅ Approved / ❌ Issues
  ☐ Document: Stakeholder_Sign_Off.txt

☐ 5.5 Code Review
  ☐ Present changes to reviewers
  ☐ Address feedback
  ☐ Obtain approval: ✅ Approved / ❌ Changes needed
  ☐ Document: Code_Review_Approval.txt

☐ 5.6 Release & Deploy
  ☐ Create git tag:
    git tag -a v1.0.0-ops-assistant -m "Release"
    git push origin v1.0.0-ops-assistant
  
  ☐ Build release image:
    docker build -t ops-assistant:v1.0.0 .
    docker tag ops-assistant:v1.0.0 ops-assistant:latest
  
  ☐ Deploy:
    docker-compose up -d ops-assistant
  
  ☐ Verify health:
    curl http://localhost:3001/api/health
  
  ☐ Smoke test:
    Ask ops-assistant a metric query
    Verify response
  
  ☐ Document: Release_Deployment.txt

☐ 5.7 Sprint Completion
  ☐ All tasks completed: ✅ Yes / ❌ No
  ☐ All tests passing: ✅ Yes / ❌ No
  ☐ No critical issues: ✅ Yes / ❌ No
  ☐ Stakeholder approved: ✅ Yes / ❌ No
  ☐ Deployed to production: ✅ Yes / ❌ No
  ☐ Document: Sprint_Completion_Summary.txt

**End of Day 5 - SPRINT COMPLETE:**
  ✅ All tests passing
  ✅ Production deployed
  ✅ Stakeholder approved
  ✅ Documentation complete
  ✅ Release tagged
```

---

## 🎯 Test Execution Summary

```bash
#!/bin/bash
# Run this script at the end of each day

echo "=========================================="
echo "TEST EXECUTION SUMMARY"
echo "=========================================="

cd web/ops-assistant

# Count passing tests
TOTAL_TESTS=$(npm test 2>&1 | grep -c "passed")
COVERAGE=$(npm test -- --coverage 2>&1 | grep "Statements" | awk '{print $NF}')

echo "Total Tests Passing: $TOTAL_TESTS"
echo "Coverage: $COVERAGE"

# Check Docker
DOCKER_STATUS=$(docker ps | grep ops-assistant | wc -l)
echo "Docker Containers Running: $DOCKER_STATUS"

# Check Health
HEALTH=$(curl -s http://localhost:3001/api/health | grep -c "healthy")
echo "Health Check: $([ $HEALTH -gt 0 ] && echo '✅ PASS' || echo '❌ FAIL')"

echo "=========================================="
```

---

## 📞 Team Communication

### Daily Standup (15 min)
**Time**: 10:00 AM daily

```
YESTERDAY:
  ✅ Completed: [Task]
  ✅ Status: X% complete

TODAY:
  📌 Planning: [Task]
  📌 Target: Complete by EOD

BLOCKERS:
  🚨 [Issue if any]
```

### Issue Escalation
- Dev blockers: Tech Lead within 1 hour
- Security issues: URGENT - within 15 min
- Test failures: Within 30 min
- Performance issues: Tech Lead within 1 hour

---

## 📊 Key Metrics to Track

### Daily Metrics
```
Day 1:
  Compile Errors:     0
  ESLint Warnings:    0
  Backend Coverage:   __% (target: 85%)
  Frontend Coverage:  __% (target: 80%)

Day 2:
  Integration Tests:  __/__ pass
  API Tests:          __/__ pass
  Docker Build:       ✅ Pass / ❌ Fail
  Compose Tests:      ✅ Pass / ❌ Fail

Day 3:
  E2E Scenario 1:     ✅ Pass / ❌ Fail
  E2E Scenario 2:     ✅ Pass / ❌ Fail
  E2E Scenario 3:     ✅ Pass / ❌ Fail
  E2E Scenario 4:     ✅ Pass / ❌ Fail
  E2E Scenario 5:     ✅ Pass / ❌ Fail
  Query Response:     ___ ms (target: <500ms)
  Memory at Start:    ___ MB (target: <150MB)

Day 4:
  Security Issues:    0 high/critical
  Documentation:      100% complete
  Compliance:         ✅ Pass / ❌ Fail
  Release Notes:      ✅ Ready / ❌ Pending

Day 5:
  Regression Tests:   100% pass
  Deployment:         ✅ Success / ❌ Failed
  Stakeholder Sign:   ✅ Approved / ❌ Issues
  Code Review:        ✅ Approved / ❌ Changes
  Production Deploy:  ✅ Live / ❌ Pending
```

---

## 🔗 Important Links & Resources

- **Main Docs**: `/workspaces/Sovereign-Mohawk-Proto/COPILOTKIT_OPS_ASSISTANT_IMPLEMENTATION.md`
- **Architecture**: `/workspaces/Sovereign-Mohawk-Proto/COPILOTKIT_OPS_ASSISTANT_ARCHITECTURE.md`
- **Sprint Plan**: `/workspaces/Sovereign-Mohawk-Proto/COPILOTKIT_OPS_ASSISTANT_SPRINT_FINALIZATION_PLAN.md`
- **Prometheus**: http://localhost:9090 (when docker-compose is up)
- **Ops Assistant**: http://localhost:3001 (when running)
- **GitHub Repo**: https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto

---

## 📝 Documentation Templates

### Test Result Template
```
COMPONENT: [Component Name]
DATE: [YYYY-MM-DD]
TESTER: [Name]

TESTS RUN:
  - Test 1: ✅ PASS / ❌ FAIL
  - Test 2: ✅ PASS / ❌ FAIL
  - Test 3: ✅ PASS / ❌ FAIL

COVERAGE: __% (target: __%)
ISSUES FOUND: [List any issues]
NEXT STEPS: [Action items]

SIGN-OFF: [Name] / [Date]
```

### Bug Report Template
```
SEVERITY: High / Medium / Low
COMPONENT: [Component]
DESCRIPTION: [What happened]
STEPS TO REPRODUCE:
  1. [Step 1]
  2. [Step 2]
  3. [Step 3]

EXPECTED: [What should happen]
ACTUAL: [What happened]
ENVIRONMENT: [OS, Browser, Node version]

SUGGESTED FIX: [If known]
```

---

## ✅ Success Criteria Checklist

### DAY 1 ✅
- [ ] Zero compile errors
- [ ] Zero ESLint errors
- [ ] Backend coverage ≥ 85%
- [ ] Frontend coverage ≥ 80%
- [ ] Security scan completed

### DAY 2 ✅
- [ ] All integration tests pass
- [ ] All API endpoints working
- [ ] Docker image builds (< 350MB)
- [ ] docker-compose stack healthy

### DAY 3 ✅
- [ ] 5/5 E2E scenarios pass
- [ ] Performance metrics captured
- [ ] All metrics accessible
- [ ] CopilotKit actions working

### DAY 4 ✅
- [ ] Security audit passed (0 critical)
- [ ] All docs complete
- [ ] Configuration validated
- [ ] Release notes ready

### DAY 5 ✅
- [ ] 100% test pass rate
- [ ] Production deployed
- [ ] Stakeholder approved
- [ ] Code reviewed and approved
- [ ] Release tagged

---

**Sprint Status**: 🟢 READY TO EXECUTE  
**Updated**: May 11, 2026
