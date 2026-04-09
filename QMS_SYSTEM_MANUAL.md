# Quality Management System (QMS) Manual

This document defines the operational QMS for Sovereign Mohawk.

This is an engineering governance artifact and not legal advice.

## Purpose

Establish repeatable controls for:

- compliance lifecycle management
- version control and release traceability
- corrective and preventive actions (CAPA)
- internal quality reviews and management signoff

## Scope

Applies to:

- runtime services, SDKs, and workflow automation
- security and privacy controls
- release evidence and post-release operational monitoring

## Roles and Responsibilities

- QMS Owner: approves process updates and annual management review
- Engineering Owner: ensures implementation of technical controls
- Security Owner: ensures risk and vulnerability controls are effective
- Operations Owner: ensures monitoring, incident response, and evidence retention
- Release Manager: ensures release gates, artifacts, and traceability are complete

## Document Control

- Controlled documents are maintained in this repository.
- Each controlled document includes:
  - owner
  - last review date
  - next review date
  - revision history entry in CHANGELOG.md when process-affecting
- Changes require pull request review and CODEOWNERS approval where applicable.

## Version and Configuration Management

- Source control: GitHub with protected main branch.
- Required controls:
  - pull request review
  - CI workflow pass status
  - dependency and security checks
- Release traceability:
  - tagged release
  - release notes
  - artifact checksums and evidence links

## CAPA Process

### Trigger Conditions

Create a CAPA ticket when any of the following occurs:

- repeated CI gate failures on the same control
- production incident severity SEV-1 or SEV-2
- vulnerability with exploitable impact
- audit finding classified as major
- post-market trend indicating control drift

### CAPA Workflow

1. Problem statement and impact definition
2. Containment action
3. Root cause analysis
4. Corrective action definition
5. Preventive action definition
6. Effectiveness verification
7. Closure approval

### CAPA Record Minimum Fields

- unique ID
- detection date
- affected versions
- impacted controls
- root cause category
- corrective action owner and due date
- preventive action owner and due date
- verification evidence links
- closure approver and closure date

## Nonconformity Handling

- Record nonconformities in issue tracker with label qms-nonconformity.
- Categorize as minor, major, or critical.
- Critical nonconformity requires immediate release block until approved mitigation.

## Internal Audit Cadence

- Monthly control-health review
- Quarterly process conformance review
- Pre-release compliance readiness review for each GA/RC cut
- Annual management review with QMS Owner signoff

## Training and Competency

- Contributors to controlled components complete onboarding on:
  - secure development and dependency hygiene
  - incident handling and evidence capture
  - documentation and traceability requirements

## Metrics and KPIs

Track at least:

- CAPA open count and aging
- mean time to corrective action closure
- repeated control failures per quarter
- release gate pass rate
- incident recurrence rate

## Evidence and Retention

Primary evidence paths include:

- results/go-live/
- results/security-audit/
- results/metrics/
- chaos-reports/

Retention baseline:

- operational evidence: minimum 12 months
- incident-linked evidence: per legal hold and contractual requirements

## Management Review Agenda (Minimum)

- KPI trend review
- open CAPA status
- internal audit findings
- external audit outcomes
- resource and tooling adequacy
- decisions and action assignments
