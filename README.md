# Customer Complaint Intelligence System

## Overview
This project implements a **Customer Complaint Intelligence System** for a mid-sized SaaS company. The system aggregates, cleans, and analyzes customer complaints across multiple channels, enabling the business to track trends, assess customer risk, monitor agent performance, and improve resolution effectiveness.

Key features:

- Sentiment and urgency scoring of complaints
- Customer risk modeling
- Complaint trend tracking by product, channel, and theme
- Operational dashboards for agent and region performance
- Weekly and monthly complaint summaries

---
---

## 1. Data Cleaning

All pre-SQL cleaning was performed in Excel. Full details are documented in Data_Cleaning.md.

Data quality was enforced before any modeling work. This included region standardization, typo correction across all tables, and systematic removal of invalid dates. These steps ensured integrity for downstream SQL analysis, DAX modeling, and Power BI reporting.

Highlights:

- Standardized regions such as Latam to Latin America.
- Corrected repeated typographical errors such as Biling to Billing.
- Replaced all invalid dates with NULL to maintain temporal consistency in SQL.
- Ensured datasets were structurally sound for joins, sentiment scoring, urgency classification, and risk modeling.
- Enabled stable inputs for the intensive SQL layer and the DAX measures developed in Power BI.

---

## 2. SQL Layer

### Indexing
Indexes were created on complaints, customers, resolutions, agents, and product_tags to improve query performance.

### Views
- customer_intelligence produces a granular complaint-level dataset.
- customer_risk computes multidimensional customer risk using volume, severity, recency, frequency, sentiment, and customer attributes.
- Additional views include complaint trends, urgency summaries, agent performance, and product or channel segmentation.

### Stored Procedures
sp_generate_complaint_summary(@period) produces weekly or monthly summaries for themes, severity, sentiment, risk, and agent performance.

### Validation Queries
Covers row counts, date integrity checks, and sampling checks for verifying the data model.

---

## 3. Power BI Layer

- Executive Summary: totals, themes, sentiment distribution.
- Customer Risk Dashboard: high-risk customers, segment patterns, tenure bands.
- Agent Performance: resolution time, backlog, ticket distribution.
- Complaint Trends: weekly patterns, product tags, sentiment dynamics.
- Drillthrough: row-level complaint inspection.

---

## 4. Skills Demonstrated

- Advanced SQL across CTEs, views, and stored procedures.
- Sentiment scoring through keyword pattern matching.
- Customer risk modeling and business logic construction.
- Data cleaning and preprocessing.
- Power BI dashboards and DAX calculations.
- Lifecycle and churn-oriented reasoning.
- Feedback loop evaluation using resolution outcomes.

---

## 5. Usage

1. Load cleaned CSV datasets into SQL Server.
2. Execute SQL scripts in order: indexing, cleaning, views, procedures, validation.
3. Connect Power BI to the database or directly to views.
4. Call sp_generate_complaint_summary with WEEKLY or MONTHLY.

---

## 6. Notes

- All transformations are documented for reproducibility.
- Date calculations assume coherent complaint_date and resolution_date formats.
- Risk scores are normalized to the 0–1 interval for comparability.
- Feedback effects can be inspected in Power BI using time-series structures.

---

## 7. References

- Data Cleaning Details: Data_Cleaning.md
- Power BI Dashboard Screenshots: stored in README_images

---

