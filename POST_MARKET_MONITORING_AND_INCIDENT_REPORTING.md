# Post-Market Monitoring and Incident Reporting Plan

This plan defines post-release monitoring, issue detection, escalation, and reporting workflows for high-risk deployments.

## Objective

Use continuous observability and structured incident handling to detect and mitigate safety, security, performance, and compliance degradation after deployment.

## Monitoring Inputs

Primary telemetry and evidence sources:

- Prometheus metrics
- Grafana dashboards
- readiness and chaos reports
- security and supply-chain scan outputs
- incident tickets and CAPA records

## Core Post-Market KPIs

- service availability and recovery latency
- proof verification latency and failure ratio
- honest ratio and Byzantine rejection trends
- privacy and policy control violation counts
- security vulnerability discovery and closure times

## Signal Review Cadence

- Daily: operational health and alert review
- Weekly: trend review and anomaly analysis
- Monthly: post-market summary and CAPA linkage review
- Per release: consolidated post-market readiness statement

## Incident Classification

- Critical: immediate severe impact, potential safety/compliance exposure
- Major: significant degradation or repeated control failures
- Minor: localized or low-impact issue

## Incident Workflow

1. Detect and triage
2. Contain and stabilize
3. Assess impact scope and affected versions
4. Trigger notification path per policy
5. Root cause analysis and CAPA creation
6. Corrective action deployment
7. Effectiveness verification
8. Closure with documented evidence

## Incident Reporting Minimum Record

- incident ID and timestamp
- severity and impacted services
- impacted versions and regions
- immediate mitigation actions
- customer/operator impact summary
- regulatory-reporting determination
- CAPA references
- closure evidence

## Notification and Escalation

- SEV-1: immediate escalation to designated owners and executive contact chain
- SEV-2: escalation within defined on-call window
- SEV-3: tracked in weekly review

## Integration with Existing Runbook

Operational execution details remain in:

- OPERATIONS_RUNBOOK.md

This file defines governance and reporting controls layered on top of the runbook actions.

## Post-Market Summary Artifact

Produce a monthly artifact containing:

- KPI trends and threshold breaches
- incidents and closure status
- open CAPAs and due-date risk
- control performance notes
- recommendations and approved actions

Suggested path:

- results/readiness/post_market_summary_YYYY-MM.md
