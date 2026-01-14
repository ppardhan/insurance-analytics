# Risks & Mitigation Plan — Insurance Analytics

## Purpose
This document identifies potential risks across data engineering,
analytics development, testing, and deployment, along with
clear mitigation strategies.

The goal is to reduce surprises during UAT and production deployment.

---

## Technical Risks

### Risk 1 — Large Data Volume Performance
**Description:**  
Fact tables may contain millions of records, leading to slow SQL queries,
refresh delays, or Power BI performance issues.

**Impact:**  
- Slow report rendering
- Refresh failures
- Poor user experience

**Mitigation Strategy:**  
- Use proper indexing and constraints in SQL
- Build gold views with optimized joins
- Enable incremental refresh in Power BI
- Validate performance early in DEV phase

---

### Risk 2 — Incorrect KPI Logic
**Description:**  
Complex business rules or DAX measures may produce incorrect KPI values.

**Impact:**  
- Loss of business trust
- Rework during UAT
- Delayed signoff

**Mitigation Strategy:**  
- Measures-first DAX approach
- Reconciliation of Power BI results with SQL truth queries
- KPI catalog locked during specifications phase

---

### Risk 3 — Data Quality Issues
**Description:**  
Nulls, duplicates, or orphan keys may exist in source or generated data.

**Impact:**  
- Incorrect analytics
- UAT rejection

**Mitigation Strategy:**  
- Automated SQL validation scripts
- Row count and reconciliation checks
- Data quality checks before Power BI consumption

---

## Process Risks

### Risk 4 — Scope Creep
**Description:**  
New requirements introduced after development has started.

**Impact:**  
- Timeline overrun
- Unplanned rework

**Mitigation Strategy:**  
- Lock requirements at Milestone M2
- Enforce acceptance criteria
- Treat new requests as future backlog items

---

### Risk 5 — UAT Delays
**Description:**  
Business users may delay testing or feedback during UAT.

**Impact:**  
- Extended project duration
- Delayed production release

**Mitigation Strategy:**  
- Dedicated UAT week in timeline
- Clear UAT test plan
- Buffer time allocated for fixes and retests

---

### Risk 6 — Production Deployment Issues
**Description:**  
Deployment may fail due to configuration, security, or refresh issues.

**Impact:**  
- Production downtime
- Loss of confidence

**Mitigation Strategy:**  
- Deployment checklist
- Rollback plan prepared in advance
- Smoke testing immediately after deployment

---

## Buffer & Contingency Strategy
- 15–20% buffer built into the plan
- Buffer used only for:
  - UAT defect fixes
  - Performance tuning
  - Documentation refinement
- No new features added during buffer period

---

## Ownership
All risks are reviewed at the end of each phase.
Mitigation actions are tracked via the GitHub Kanban board.
