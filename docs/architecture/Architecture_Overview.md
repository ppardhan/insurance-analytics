# Architecture Overview

## Objective
Build an end-to-end Insurance Analytics solution using SQL (data source + modeling) and Power BI (semantic model + reporting) with enterprise-grade DEV / UAT / PROD delivery.

## High-level Architecture
- SQL Layer: stg_* → dim_* / fact_* → vw_gold_*
- Power BI Layer: Dataset (Semantic Model) → Reports
- Governance: GitHub version control, testing, UAT signoff, controlled PROD releases

## Key Design Decisions
- SQL database is the single source of truth.
- Curated SQL views (vw_gold_*) act as the contract to Power BI.
- Measures-first approach in DAX; minimal calculated columns.
- Incremental refresh based on transaction and date dimensions.
- Row-Level Security (RLS) implemented in the semantic model.

## Non-Functional Requirements
- Scale:
  - Policies: ~5M
  - Premium Transactions: ~50M
  - Claims: ~5M
- Performance:
  - Core report pages load < 5 seconds
  - Refresh SLA documented and monitored
- Accuracy:
  - KPI reconciliation against SQL validation queries

## Artifacts Produced
- Architecture diagrams
- Data models (ERD)
- SQL DDL and transformation scripts
- Gold-layer SQL views
- Power BI semantic model and reports
- Testing and UAT documentation
