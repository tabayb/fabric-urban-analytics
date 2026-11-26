# Platform Architecture

## End-to-End Data Flow

```mermaid
flowchart TD
    subgraph Sources["External Data Sources"]
        TLC["NYC TLC - Taxi and Zones"]
        AQ["OpenAQ - PM2.5 and NO2"]
        ECB["ECB - Exchange Rates"]
        WB["World Bank - GDP"]
        EPA["US EPA - Hourly NO2"]
    end

    subgraph Ingestion["Data Ingestion"]
        PL["Fabric Data Pipelines"]
        DF["Dataflow Gen2"]
        NB["Python Notebook"]
    end

    TLC --> PL
    AQ --> PL
    AQ --> DF
    ECB --> PL
    ECB --> DF
    WB --> PL
    WB --> DF
    EPA --> NB

    subgraph LH["OneLake - UrbanAnalyticsLH"]
        B["Bronze - Raw Data"]
        STG["Staging Tables"]
        S["Silver - Cleansed Data"]
        G["Gold - Analytical Data"]
        B --> S
        STG --> S
        S --> G
    end

    PL --> B
    DF --> STG
    NB --> B

    G --> WH["UrbanAnalyticsWH - 10 Tables"]
    WH --> SM["Semantic Model - 8 Tables"]
    SM --> BI["Power BI - 6 Report Pages"]

    ORCH["Master ETL Pipeline"]
    ORCH -.-> PL
    ORCH -.-> S
    ORCH -.-> G
    ORCH -.-> WH

    classDef bronze fill:#CD7F32,color:#fff,stroke:#995c20
    classDef silver fill:#C0C0C0,color:#222,stroke:#888
    classDef gold fill:#EAB308,color:#222,stroke:#A16207
    classDef analytics fill:#2563EB,color:#fff,stroke:#1E40AF
    classDef orchestration fill:#7C3AED,color:#fff

    class B bronze
    class S silver
    class G gold
    class WH,SM,BI analytics
    class ORCH orchestration
```

## Architecture Notes

- Solid arrows represent data flow.
- Dashed arrows represent orchestration.
- PySpark notebooks implement Silver and Gold transformations.
- T-SQL scripts refresh the main Warehouse tables.
- Power BI consumes analytical data through the semantic model.
- Selected OpenAQ and EPA ingestion workflows are maintained separately from the automated master pipeline.
- EPA-specific Warehouse tables are not included in the current Power BI semantic model.
- API credentials must be configured separately.
