# DCI Biometics Study Analysis Plan

## Summary

## Data Flow Diagram

```mermaid
flowchart TD
    A(["MyPhD Data"]) --> B["02_Pulling_MVPA.R"] & C@{ label: "<span style=\"padding-left:\">01_Pulling_Steps.R</span>" } & D["03_Pulling_Sleep.R"]
    C --> E["daily.steps.Rdata"]
    B --> F["daily_mvpa.Rdata"]
    D --> G["daily_sleep.Rdata"]
    H["04_trudiagnostics.R"] --> I["trudiagnositcs.R"]
    E --> J@{ label: "<span class=\"nodeLabel\">05_Biometics_Cohort.R</span>" }
    F --> J
    G --> J
    I --> J
    K["2024 Master List.xlsx"] --> J
    J --> L["Biometrics.Rdata"]
    L --> M["06_Biometics_Analysis.R"]
    C@{ shape: rect}
    J@{ shape: rect}
    L@{ shape: rect}
    style M stroke:#D50000

```
## Data Sources

- Wearables Data: https://drive.google.com/drive/folders/1-620o1al0SIuvaSOfgV1gNzT2OJN6rH7?usp=drive_link
  - Prior to analyses, update file in Terminal.
    
      gsutil -m cp -r "gs://dci-wellness-study" "/Users/lauragraham/Library/CloudStorage/GoogleDrive-lagraham@stanford.edu/Shared drives/Secure: DCI Research/Analysis_Graham/Wearables Data/Data Downloads"
    
      May also require: % gcloud auth login. 

- TruDiagnostics Data: https://drive.google.com/drive/folders/18DAzDidiQoPj5Sf7qeJf2vb6WxW1plLe?usp=drive_link
