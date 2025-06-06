# DCI Biometics Study Analysis Plan

## Summary
Emerging research supports the hypothesis that participation in programs like the Stanford Distinguished Careers Institute (DCI) can positively impact biological age and health metrics. The DCI is intentionally designed to foster personal renewal, community engagement, and recalibration of wellness—three pillars independently correlated with improved longevity and health outcomes[1]. Recent large-scale studies have demonstrated that higher educational attainment and purposeful engagement are associated with a slower pace of biological aging, as measured by advanced epigenetic clocks such as DunedinPACE, and with reduced mortality risk[3].  

Furthermore, the integration of wearable devices into health research has enabled objective, continuous measurement of physical activity, sleep, and related health behaviors; higher volumes and intensities of device-measured physical activity, as well as healthier sleep patterns, have been robustly linked to lower all-cause mortality and reduced risk of chronic disease[2][4]. Stanford’s own research initiatives highlight the utility of wearables for personalized health monitoring and early detection of health changes, reinforcing the value of such metrics in tracking intervention outcomes. Collectively, these findings suggest that structured, purpose-driven educational programs like DCI—when combined with ongoing assessment of health behaviors via wearables—are well-positioned to yield measurable improvements in biological aging and overall health.

References  
[1] Stanford Distinguished Careers Institute https://longevity.stanford.edu/stanford-distinguished-careers-institute/  
[2] Strain T, Wijndaele K, Dempsey PC, Sharp SJ, Pearce M, Jeon J, Lindsay T, Wareham N, Brage S. Wearable-device-measured physical activity and future health risk. Nat Med. 2020 Sep;26(9):1385-1391. doi: 10.1038/s41591-020-1012-3. Epub 2020 Aug 17. PMID: 32807930; PMCID: PMC7116559. https://pmc.ncbi.nlm.nih.gov/articles/PMC7116559/  
[3] Graf GHJ, Aiello AE, Caspi A, Kothari M, Liu H, Moffitt TE, Muennig PA, Ryan CP, Sugden K, Belsky DW. Educational Mobility, Pace of Aging, and Lifespan Among Participants in the Framingham Heart Study. JAMA Netw Open. 2024 Mar 4;7(3):e240655. doi: 10.1001/jamanetworkopen.2024.0655. PMID: 38427354; PMCID: PMC10907927. https://pmc.ncbi.nlm.nih.gov/articles/PMC10907927/  
[4] Zheng, N.S., Annis, J., Master, H. et al. Sleep patterns and risk of chronic disease as measured by long-term monitoring with commercial wearable devices in the All of Us Research Program. Nat Med 30, 2648–2656 (2024). https://doi.org/10.1038/s41591-024-03155-8. https://www.nature.com/articles/s41591-024-03155-8  

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
