# Architecture notes

## Data flow

1. **Source:** `dataset/hospital_raw.csv` is the supplied flat-file extract.
2. **Staging (`stg`):** The source is landed in a raw staging table. The landing layer is intended to preserve source values for traceability and replay.
3. **Operational Data Store (`ods`):** The staging data is transformed into typed, related entities and organised into a normalised relational structure.
4. **Data Warehouse (`dw`):** The ODS data is loaded into fact and dimension tables for analytical use. The model uses dimensional modelling concepts, including surrogate keys and historical dimension handling where implemented.
5. **Audit (`audit`):** Load-control and data-quality tables support operational traceability and validation.

## Design principles

- Separate ingestion from transformation and analytical presentation.
- Preserve the original extract in the landing layer.
- Enforce relational integrity in the operational model.
- Define fact-table grain before loading measures.
- Use dimensions to provide descriptive context for facts.
- Record load and validation outcomes so failures can be investigated.

## Important implementation notes

- The CSV is a supplied source file; a live Oracle extraction process is outside the repository scope.
- Update the CSV path in the bulk-load script before execution.
- Review destructive DDL and `TRUNCATE` statements before running scripts against any database containing data you need.
- Use the SQL scripts as the authoritative implementation reference; this document describes the intended layer responsibilities.
