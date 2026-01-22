# Project Plan & Timeline

## 1. Project Goal
The goal of this project is to design and deliver an **end-to-end, enterprise-grade Insurance Analytics solution** using:
- SQL for data modeling, data generation, and transformations
- Power BI for semantic modeling, advanced DAX, and reporting

This project is portfolio-focused and demonstrates:
- Large-scale data handling (millions of records)
- Advanced SQL and DAX skills
- Enterprise delivery lifecycle (DEV → UAT → PROD)
- Strong documentation, governance, and testing practices

---

## 2. Project Basics
- Project Name: Insurance Analytics
- Start Date: 16 Jan 2026
- Duration: 3 Weeks
- Effort: ~24 hours/week (≈72 total hours)
- Delivery Model: DEV → UAT → PROD

---

## 3. Timeline Summary (High Level)

| Week | Focus Area | Key Outcome |
|-----|-----------|-------------|
| Week 1 | SQL Data Engineering | Gold-ready SQL model with large-scale data |
| Week 2 | Specs + Power BI Core | Business-approved KPIs + semantic model |
| Week 3 | Advanced DAX, UAT & PROD | Production-ready solution & portfolio |

---

## 4. Detailed Week-by-Week Plan

### Week 1 (16–22 Jan 2026) — SQL Foundation & Data Engineering
**Activities**
- Create database schemas
- Build dimension and fact tables
- Generate large-scale insurance data  
  (Policies ~5M, Premium Transactions ~50M, Claims ~5M)
- Create curated Gold views (`vw_gold_*`)
- Implement SQL validation checks:
  - Row count checks
  - Reconciliation checks
  - Data quality checks
- Document ERD and data dictionary

**Deliverables**
- SQL DDL and ETL scripts
- Gold views ready for reporting
- SQL validation scripts
- Data model documentation

**Exit Check**
- All fact and dimension tables created
- Gold views stable and queryable
- Validation queries passing
- Data model documentation completed

---

### Week 2 (23–29 Jan 2026) — Specifications & Power BI Core Build
**Activities**
- Create Business Requirements Document (BRD)
- Create Functional Specification
- Create Design Specification
- Connect Power BI to SQL Gold views
- Build star schema semantic model
- Create Date table and relationships
- Implement base and intermediate DAX measures
- Design report wireframes and layout

**Deliverables**
- BRD, Functional Spec, Design Spec
- Power BI semantic model
- Base DAX measures
- Initial report structure

**Exit Check**
- KPIs reviewed and locked
- Semantic model relationships validated
- Base measures producing correct results

---

### Week 3 (30 Jan–05 Feb 2026) — Advanced DAX, QA, UAT & Production
**Activities**
- Implement advanced DAX:
  - YoY, MoM, Rolling metrics
  - Rankings and % contribution
  - Dynamic titles and conditional formatting
- Implement Row-Level Security (RLS)
- Configure incremental refresh
- Perform performance tuning
- Execute UAT and close issues
- Deploy solution to PROD
- Capture screenshots and finalize documentation

**Deliverables**
- Advanced DAX measures
- RLS and incremental refresh configuration
- UAT signoff document
- Production deployment guide
- Post-deployment report
- Portfolio-ready README and assets

**Exit Check**
- UAT signed off
- Production deployment successful
- Performance and security validated
- Repository ready for portfolio use

---

## 5. Governance & Tracking

### Project Tracking
- GitHub Project Board (Kanban) used for tracking progress
- Work organized into EPICs and Tasks
- Daily progress tracked by moving cards across columns:
  - Backlog → To Do → In Progress → In Review → Done

### Version Control
- `main` branch: production-ready code
- `dev` branch: integration branch
- `feature/*` branches: individual work items
- Production releases marked using Git tags

### Documentation Governance
- All decisions recorded in `Decisions_Log.md`
- Each phase produces documented deliverables
- No phase proceeds without exit criteria being met

### Quality & Control
- SQL validation scripts executed before Power BI build
- UAT required before production deployment
- Rollback and post-deployment validation documented
