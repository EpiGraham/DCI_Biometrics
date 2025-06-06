# DCI Biometics Study Analysis Plan

Summary:

Data Sources: 
- Wearables Data: https://drive.google.com/drive/folders/1-620o1al0SIuvaSOfgV1gNzT2OJN6rH7?usp=drive_link
  - Prior to analyses, update file in Terminal.
    
      gsutil -m cp -r "gs://dci-wellness-study" "/Users/lauragraham/Library/CloudStorage/GoogleDrive-lagraham@stanford.edu/Shared drives/Secure: DCI Research/Analysis_Graham/Wearables Data/Data Downloads"
    
      May also require: % gcloud auth login. 

- TruDiagnostics Data: https://drive.google.com/drive/folders/18DAzDidiQoPj5Sf7qeJf2vb6WxW1plLe?usp=drive_link

```mermaid
---
config:
  theme: redux
---
flowchart TD
    A(["MyPhD Data"])
    A --> B["01_Pulling_Steps.R"]
    A --> C["02_Pulling_MVPA.R"]
    A --> D["03_Pulling_Sleep.R"]
    C --> E["daily.mvpa.Rdata"]
    B --> F["daily_steps.Rdata"]
    D --> G["daily_sleep.Rdata"]

    H["04_trudiagnostics.R"]
        H --> I["trudiagnostics.R"]

    K["2024 Master List.xlsx"]

    E --> J["05_Biometics_Cohort.R"]
    F --> J["05_Biometics_Cohort.R"]
    G --> J["05_Biometics_Cohort.R"]
    I --> J["05_Biometics_Cohort.R"]
    K --> J["05_Biometics_Cohort.R"]

  J --> L["06_Biometics_Analysis.R"]

```
