# MediCore | Healthcare Data Warehouse Project

An end-to-end SQL Server data warehousing case study that transforms a denormalised hospital operations extract into a structured, analytics-ready data warehouse.

> **Project type:** Simulated portfolio case study  
> **Platform:** Microsoft SQL Server  
> **Language:** T-SQL  
> **Architecture:** Staging → Operational Data Store (3NF) → Dimensional Data Warehouse (Star Schema)

## Project overview

Healthcare operational data often combines patient, appointment, clinical, billing, laboratory, pharmacy and insurance information in a single wide extract. This design can introduce duplication, update anomalies, inconsistent business rules and make reporting difficult to scale.

This project demonstrates how to build a layered SQL Server data warehouse from a supplied CSV dataset. The source contains approximately 5,000 records and 49 business columns. The pipeline lands the source data, transforms it into a normalised operational model, and then loads a dimensional model for analytical querying.

**Scope note:** The supplied CSV is used as the source extract. This repository does not implement or claim a live connection to Oracle ERP, a production hospital system, or a real client environment. Treat MediCore as a fictional/simulated business scenario. Do not interpret the sample data as real patient records.

## Architecture

```text
                Source CSV
             hospital_raw.csv
                     |
                     v
          +----------------------+
          |  STAGING (stg)       |
          |  Raw landing layer   |
          |  Source preservation |
          +----------------------+
                     |
                     v
          +----------------------+
          |  OPERATIONAL (ods)   |
          |  Cleansing           |
          |  Data type handling  |
          |  3NF normalisation   |
          +----------------------+
                     |
                     v
          +----------------------+
          |  DATA WAREHOUSE (dw) |
          |  Star schema         |
          |  Fact & dimensions   |
          |  Surrogate keys      |
          +----------------------+
                     |
                     v
           Analytics-ready data

       AUDIT (audit) supports load
       tracking, rejected rows and
       data-quality test results.
```

| Layer | Purpose |
|---|---|
| `stg` | Preserves the incoming source extract in a raw landing structure. |
| `ods` | Cleans, types and organises operational entities using a normalised relational model. |
| `dw` | Stores analytical data in a dimensional star schema. |
| `audit` | Tracks load execution, rejected records and data-quality outcomes. |

The layers are conceptually comparable to Bronze, Silver and Gold in a medallion architecture: `stg` ≈ Bronze, `ods` ≈ Silver, and `dw` ≈ Gold.

## Key implementation areas

- **Data ingestion:** Loads CSV data into SQL Server using `BULK INSERT`.
- **Layered architecture:** Separates raw ingestion, operational transformation, dimensional modelling and audit functions.
- **Data modelling:** Converts a wide source structure into a normalised ODS and a dimensional warehouse.
- **Dimensional modelling:** Implements fact and dimension tables using a Kimball-style star schema.
- **Surrogate keys:** Uses warehouse keys to connect facts to dimensions.
- **Historical tracking:** Includes Slowly Changing Dimension Type 2 logic in the dimensional load implementation.
- **Auditability:** Maintains load-control and data-quality records.
- **Data validation:** Includes SQL tests for reconciliation, integrity and business-rule checks.

Refer to the SQL scripts for the exact implemented objects and transformation logic.

## Repository contents

```text
MediCore-Healthcare-Data-Warehouse/
├── README.md
├── dataset/
│   └── hospital_raw.csv
├── sql/
│   ├── 01_create_staging_tables.sql
│   ├── 02_bulk_data_ingestion.sql
│   ├── 03_audit_control_tables.sql
│   ├── 04_load_staging_to_ods.sql
│   ├── 05_ods_normalization.sql
│   ├── 06_create_dw_star_schema.sql
│   ├── 07_load_ods_to_dw.sql
│   └── 08_data_validation_tests.sql
└── docs/
    └── architecture.md
```

## Prerequisites

- Microsoft SQL Server (the scripts were prepared for SQL Server 2019 syntax).
- SQL Server Management Studio (SSMS).
- Permission for the SQL Server Database Engine service account to read the CSV file.
- A local copy of this repository.

## How to run

1. Clone or download this repository.
2. Create a database named `MediCoreDW` in SQL Server.
3. Open the scripts in the `sql/` folder using SSMS.
4. Review the scripts before execution. Some scripts contain `DROP`, `TRUNCATE` or table-recreation statements and can remove existing data or objects.
5. Execute the scripts in the numbered order, checking each stage before moving to the next.
6. In `02_bulk_data_ingestion.sql`, change the `BULK INSERT` file path to the actual location of `dataset/hospital_raw.csv` on the SQL Server machine. The SQL Server service account must have read access to that path.
7. Run the validation script and review the recorded test results.

**Important:** `BULK INSERT` reads the file from the SQL Server host, not necessarily from the computer running SSMS. Adjust file permissions and path accordingly. Review database names, object dependencies and load behaviour for your environment before running.

## Data quality and validation

The project includes a dedicated validation script. The documentation supplied with the original project reports a billing arithmetic assertion failure in the sample extract. This is treated as a data-quality finding to investigate and report, rather than silently changing the source values.

Run the validation SQL in your own environment to reproduce the results. Do not present sample findings as production business outcomes.

## Skills demonstrated

**SQL Server & T-SQL:** DDL, DML, `BULK INSERT`, views, joins, stored procedures, constraints and data transformations.

**Data Engineering:** ETL pipeline design, staging, ODS, batch loading, audit logging, data lineage and validation.

**Data Modelling:** 3NF normalisation, dimensional modelling, star schema, fact tables, dimension tables and surrogate keys.

**Data Quality:** Reconciliation, referential integrity and business-rule validation.

## Potential enhancements

- Add a single orchestration stored procedure to execute the pipeline end to end.
- Add incremental ingestion with a reliable watermark and restart-safe processing.
- Add automated test execution and a run summary.
- Connect the warehouse to Power BI and publish a report with a documented semantic model.
- Add an ERD and a star-schema diagram to the documentation.

## Disclaimer

This is an educational portfolio project using a supplied sample CSV and a simulated healthcare business scenario. It is not affiliated with or endorsed by any real healthcare provider. No live production-system integration is represented. Verify that the dataset is safe and licensed for public redistribution before publishing it.
