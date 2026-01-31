# Insurance Analytics — Architecture Design

## 1. Objective
Build an end-to-end Insurance Analytics solution using SQL Server as the source and Power BI for reporting, with enterprise GitHub discipline, UAT, and production readiness.

## 2. Target Audience
- Business: Leadership / Management
- Technical: Data/BI team (developers, reviewers, support)

## 3. End-to-End Data Flow (High Level)
SQL Server (insurance_DB)
→ Core DW schema (core dimensions & facts)
→ Standard naming views (core.vw_fact_*)
→ Power BI semantic model
→ Reports & dashboards
→ UAT validation + sign-off
→ Production deployment + monitoring

## 4. Components
### 4.1 Data Platform
- SQL Server database: insurance_DB
- Schemas:
  - core (dimensions, facts, views)
  - stg (helper_numbers)
  - audit (audit_load_log + procedures)

### 4.2 Reporting Layer
- Power BI Desktop for development
- Power BI Service for deployment (Dev/UAT/Prod workspaces)

## 5. Data Modeling Approach
- Star schema (facts in center, dimensions around)
- Date dimension: core.dim_date
- Fact naming standardization: core.vw_fact_premium_txn, core.vw_fact_claim

## 6. Operational Governance
- Audit logging: audit.audit_load_log
- Branching: main / dev / feature/*
- Project board tracking: Epics → tasks → daily updates

## 7. Non-Functional Requirements (NFRs)
- Performance: model optimized, minimal DAX overhead, efficient refresh
- Refresh SLA: to be finalized in UAT/Prod plan
- Accuracy: reconciliation checks between SQL and Power BI
- Security: RLS (dynamic) + role testing

## 8. Open Items (to be completed Day 1)
- Architecture diagram (draw.io)
- ERD / star schema diagram (draw.io)
