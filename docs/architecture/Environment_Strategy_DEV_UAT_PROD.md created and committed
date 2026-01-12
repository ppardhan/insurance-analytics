# SQL vs DAX Responsibility Matrix

## Principles
- SQL handles data shaping, cleansing, and reusable logic.
- DAX handles context-aware analytics and interactive calculations.
- Logic should exist in one place only (no duplication).

## Implement in SQL (Data Engineering Layer)
- Data type standardization and null handling
- Joins and relationship integrity
- Deduplication and data cleansing
- Dimension and fact table modeling
- Grain enforcement and key management
- Slowly Changing Dimension (SCD) preparation
- Reusable aggregations used across multiple reports
- Data quality checks (nulls, duplicates, orphan keys)
- Curated gold-layer views (`vw_gold_*`)

## Implement in DAX (Semantic / Analytics Layer)
- KPI calculations dependent on filter context
- Time intelligence (YoY, MoM, YTD, R12)
- Rankings and Top-N analysis
- Percent-of-total and contribution analysis
- What-if parameters and disconnected slicers
- Dynamic titles and conditional formatting
- User-driven calculations requiring interactivity

## Decision Rules
- If logic is stable and reused across reports → prefer SQL
- If logic depends on user filters/slicers → prefer DAX
- Avoid calculated columns unless absolutely necessary
- Measures-first modeling approach

## Outcome
- Clean separation of concerns
- Better performance and scalability
- Easier maintenance and debugging
- Clear ownership between data engineering and analytics layers
