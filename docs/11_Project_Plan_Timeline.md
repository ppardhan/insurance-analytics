# Project Plan & Timeline — Insurance Analytics

## Inputs (Locked)
- Start date: 13 Jan 2026
- Duration: 6 weeks
- Effort: 21 hrs/week
- Delivery lifecycle: DEV → UAT → PROD

## Project Goal
Build a production-grade Insurance Analytics solution where:
- SQL handles data engineering (staging → core → gold views)
- Power BI handles semantic modeling, DAX, and reporting
- Delivery follows enterprise promotion gates with validation

---

## Timeline Summary (High Level)

| Week | Phase | Focus | Milestone |
|-----|------|-------|-----------|
| 1–2 | Phase 1 | SQL Data Engineering | M1 |
| 3 | Phase 2 | Requirements & Specs | M2 |
| 4 | Phase 3 | Power BI Build | M3 |
| 5 | Phase 4 | QA & Readiness | M4 |
| 6 | Phase 5–7 | UAT → PROD → Portfolio | M5–M7 |

---

## Detailed Week-by-Week Plan

### Week 1 (13–19 Jan 2026) — SQL Model Foundation
**Objective:** Establish a correct, scalable core data model.

**Activities**
- Define business grain for each fact table
- Design dimensions: policy, customer, agent, product, date
- Design fact tables: premium, claims
- Create staging tables (stg_*)
- Implement initial DDL scripts
- Load synthetic data for validation

**Effort:** ~21 hrs  
**Exit Check:** DDL scripts exist and data loads run without errors

---

### Week 2 (20–26 Jan 2026) — Gold Views & SQL Validation (M1)
**Objective:** Make SQL layer reporting-ready.

**Activities**
- Build `vw_gold_*` views as reporting contracts
- Implement data-quality checks (nulls, duplicates, orphan keys)
- Implement reconciliation queries for core KPIs
- Add indexes and constraints
- Run performance sanity checks

**Exit Check (M1):** Gold views stable and validation checks pass

---

### Week 3 (27 Jan–2 Feb 2026) — Requirements & Specifications (M2)
**Objective:** Lock scope before analytics build.

**Activities**
- Create Business Requirement Document (BRD)
- Build KPI catalog (definitions, formulas, grain)
- Design report wireframes
- Create Functional Specification
- Create Design Specification
- Define acceptance criteria

**Exit Check (M2):** Specifications approved and scope frozen

---

### Week 4 (3–9 Feb 2026) — Power BI Model & Report Build (M3)
**Objective:** Build feature-complete analytics in DEV.

**Activities**
- Build semantic model on `vw_gold_*`
- Implement measures-first DAX
- Add time intelligence (YoY, MoM, R12)
- Build report pages per wireframes
- Initial refresh and validation

**Exit Check (M3):** All pages and measures implemented in DEV

---

### Week 5 (10–16 Feb 2026) — QA, Performance & Security (M4)
**Objective:** Prepare a release candidate.

**Activities**
- Implement Row-Level Security (RLS)
- Configure incremental refresh
- Use Performance Analyzer for tuning
- Reconcile Power BI results with SQL
- Prepare UAT test plan

**Exit Check (M4):** Release candidate ready for UAT

---

### Week 6 (17–23 Feb 2026) — UAT, PROD & Portfolio (M5–M7)
**Objective:** Signoff, deploy, and package.

**Activities**
- Execute UAT and resolve issues
- Obtain UAT signoff
- Prepare release notes and rollback plan
- Deploy to PROD and run smoke tests
- Update README with project story
- Add screenshots and walkthrough notes

**Exit Checks**
- M5: UAT signoff complete
- M6: Production live and validated
- M7: Repository portfolio-ready

---

## Governance & Tracking
- Work tracked via GitHub Kanban board
- Tasks move: Backlog → To Do → In Progress → In Review → Done
- Promotion follows DEV → UAT → PROD discipline
