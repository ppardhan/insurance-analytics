Functional Specification Document
Project: Insurance Analytics – SQL + Power BI

1. Purpose of Functional Specification
This Functional Specification document translates business requirements defined in the BRD into clear, unambiguous analytical definitions.
It acts as a contract between business, data engineering, and BI layers, ensuring consistent KPI interpretation, clear ownership between SQL and Power BI, and avoidance of data grain mismatches.

2. KPI Responsibility Matrix (SQL vs Power BI)
Raw data extraction – SQL
Base aggregations – SQL
Business rules – SQL
Time intelligence (YoY, MoM) – Power BI (DAX)
UI-level calculations – Power BI (DAX)
Formatting & labels – Power BI

3. Standard KPI Definition Template
KPI Name
Business Description
Grain (row-level meaning)
Primary Fact Table
Supporting Dimensions
Filters / Conditions
Calculation Owner (SQL / DAX)
Refresh Dependency

4. KPI Catalog (High-Level)
Policy KPIs: Total Active Policies, New Policies Issued, Policy Renewal Rate
Premium KPIs: Gross Premium, Net Premium, Premium Collection Rate
Claims KPIs: Total Claims, Claims Severity, Claim Settlement Ratio
Customer KPIs: Active Customers, Customer Retention Rate
Operational KPIs: Average Claim Processing Time

5. Grain Validation Summary
fact_policy – One row per policy
vw_fact_premium_txn – One row per premium transaction
vw_fact_claim – One row per claim
fact_claim_payment – One row per payment
fact_policy_renewal – One row per renewal event

6. Assumptions & Dependencies
Star schema remains stable
Date dimension is complete and continuous
All facts reference valid dimension keys
Audit logs track load completeness
