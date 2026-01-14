# Milestones & Exit Criteria — Insurance Analytics

## Purpose
This document defines formal milestones used to control phase transitions
across DEV → UAT → PROD. Each milestone has clear entry and exit criteria.

No phase is considered complete unless its exit criteria are met.

---

## M1 — SQL Model Ready for Reporting

### Entry Criteria
- Raw data generation/loading scripts available
- Modeling assumptions documented
- Staging tables created

### Exit Criteria
- All dimension tables (`dim_*`) created
- All fact tables (`fact_*`) created
- Business grain clearly enforced
- Primary/foreign keys defined
- Gold views (`vw_gold_*`) created
- SQL validation checks pass:
  - No unexpected nulls
  - No duplicate keys
  - No orphan records

**Outcome:** Power BI can safely connect to SQL gold views.

---

## M2 — Requirements & Specifications Approved

### Entry Criteria
- SQL model stable
- Gold views validated

### Exit Criteria
- Business Requirement Document approved
- KPI catalog finalized and frozen
- Report wireframes approved
- Functional Specification completed
- Design Specification completed
- Acceptance criteria documented

**Outcome:** Scope is locked; no new requirements allowed.

---

## M3 — Report Feature Complete (DEV)

### Entry Criteria
- Specifications approved (M2)
- Gold views unchanged

### Exit Criteria
- Semantic model built
- Relationships validated
- All DAX measures implemented
- Time intelligence measures validated
- All report pages built per design
- No missing functional requirements

**Outcome:** Feature-complete report in DEV.

---

## M4 — Release Candidate Ready

### Entry Criteria
- Feature-complete report (M3)

### Exit Criteria
- Row-Level Security implemented and tested
- Incremental refresh configured and tested
- Performance Analyzer results acceptable
- Power BI KPIs reconciled with SQL truth
- No critical defects open

**Outcome:** Report ready for UAT.

---

## M5 — UAT Signoff

### Entry Criteria
- Release candidate deployed to UAT
- UAT test plan approved

### Exit Criteria
- All UAT test cases executed
- All critical issues resolved
- Remaining issues documented and accepted
- Formal UAT signoff received

**Outcome:** Business approval to go live.

---

## M6 — Production Live

### Entry Criteria
- UAT signoff complete
- Release notes prepared
- Rollback plan approved

### Exit Criteria
- Production deployment successful
- Smoke tests passed
- Refresh schedules verified
- Monitoring enabled

**Outcome:** Solution live for end users.

---

## M7 — Portfolio Ready

### Entry Criteria
- Production deployment completed

### Exit Criteria
- README updated with project narrative
- Screenshots added
- Walkthrough documentation completed
- Repo organized and clean

**Outcome:** Project ready for interviews and demos.
