Business Requirements Document (BRD)
Project: Insurance Analytics – SQL + Power BI

1. Business Context & Problem Statement
The insurance organization operates across policies, premiums, claims, renewals, agents, and customers. Currently, data is fragmented across multiple systems, resulting in delayed reporting, inconsistent metrics, and limited visibility into business performance.
Leadership and operational teams lack a unified view of customer lifecycle, revenue realization, risk exposure, and claims settlement efficiency.
This project aims to build a centralized analytics solution to provide timely, accurate, and actionable insights.
2. Project Objectives (Business Goals)
• Establish a single source of truth for insurance analytics.
• Enable leadership to monitor growth, profitability, and risk.
• Improve transparency and efficiency in claims processing.
• Support data-driven decisions across sales, operations, and finance.
3. Scope Definition
In Scope:
• Policy lifecycle analytics (issuance, active, renewal, lapse).
• Premium collection and payment behavior.
• Claims frequency, severity, and settlement analysis.
• Customer retention and segmentation.
• Agent and sales channel performance.

Out of Scope:
• Real-time streaming analytics.
• Predictive modeling or machine learning.
• External third-party system integrations.

4. Target Users / Personas
CEO / CXO: Strategic overview of growth, risk, and profitability.
Head of Operations: Operational efficiency, claims turnaround, bottlenecks.
Claims Manager: Claims volume, severity, settlement ratios.
Sales Head: Policy sales, renewals, agent/channel performance.
Finance Team: Premium realization, revenue leakage, payouts.

5. KPI Catalog (High-Level)
Policy KPIs: Total Active Policies, New Policies Issued, Renewal Rate, Lapse Rate.
Premium KPIs: Gross Premium, Net Premium, Collection Rate, Overdue Premiums.
Claims KPIs: Number of Claims, Claims Frequency, Claims Severity, Settlement Ratio.
Customer KPIs: Active Customers, Retention Rate, High-Risk Customers.

6. Success Criteria / Acceptance Criteria
• Data accuracy of at least 99% compared with SQL source.
• All KPIs validated and reconciled.
• Defined and met data refresh SLA.
• Role-based access (RLS) tested and approved.
• Business user sign-off completed in UAT.

7. Assumptions & Constraints
• Dataset is synthetic but business-realistic.
• SQL Server is the system of record.
• Power BI is the reporting and visualization layer.
• Data refresh is batch-based.

8. Risks & Mitigations
Risk: Performance issues due to large data volume.
Mitigation: Star schema design and optimized SQL.

Risk: Misinterpretation of KPIs.
Mitigation: Clear documentation and definitions.

Risk: Refresh or deployment failures.
Mitigation: Audit logging and controlled deployment process.
