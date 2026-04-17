[![Review Assignment Due Date](https://classroom.github.com/assets/deadline-readme-button-22041afd0340ce965d47ae6ef1cefeee28c7c493a6346c4f15d667ab976d596c.svg)](https://classroom.github.com/a/FxAEmrI0)
# Actuarial Theory and Practice A

---
Team Members: Lisa Cheng, Yi Yao Wang, Connie Gu, Deetya Jugnarain

## Project Overview
This project develops actuarial insurance solutions for Cosmic Quarry Mining Corporation (CQMC), focusing on pricing, risk assessment, and product design across its interstellar mining operations. The aim is to provide data-driven recommendations to Galaxy General Insurance Company (GGIC) on how to structure insurance products that effectively manage risk while maintaining profitability.

The analysis covers four key hazard areas, each representing a distinct source of operational risk:
- Equipment Failure: Low-frequency, high-severity breakdowns of specialised mining machinery, requiring protection against large, unexpected losses.
  
- Cargo Loss: Low-frequency and high-severity events driven primarily by environmental hazards. Requires policy to protect policyholders from catastrophic losses as CQMC expands its mining operations and interstellar transportation networks.
  
- Workers’ Compensation: High-frequency, moderate-severity claims arising from workplace injuries in mining operations. Risk is driven by factors such as worker experience, safety compliance and operational intensity. As CQMC expands its workforce across multiple solar systems, exposure to workplace incidents increases, requiring structured coverage to manage frequent claims while protecting against more severe injury events.
  
- Business Interruption: Low-frequency and high-severity risk profile, with many policies recording no claims but a few very large losses creating a right-skewed distribution. This means extreme losses remain important for pricing and capital planning. The proposed Operational Continuity Cover (OCC) protects against downtime-related losses, with a time deductible targeting major interruptions and a monetary deductible plus policy limit helping control smaller and very large claims.

---
## Data
Our pricing models are calibrated using historical claims experience from comparable products within GGIC’s existing portfolio, and can be accessed here:
- [Equipment Failure Claims](https://www.soa.org/globalassets/assets/files/research/opportunities/2026/student-research-case-study/srcsc-2026-claims-equipment-failure.xlsx)
- [Workers Compensation Claims](https://www.soa.org/globalassets/assets/files/research/opportunities/2026/student-research-case-study/srcsc-2026-claims-workers-comp.xlsx)
- [Business Interruption Claims](https://www.soa.org/globalassets/assets/files/research/opportunities/2026/student-research-case-study/srcsc-2026-claims-business-interruption.xlsx)
- [Cargo Loss Claims](https://www.soa.org/globalassets/assets/files/research/opportunities/2026/student-research-case-study/srcsc-2026-claims-cargo.xlsx)
- [Interest and Inflation Rates](https://www.soa.org/globalassets/assets/files/research/opportunities/2026/student-research-case-study/srcsc-2026-interest-and-inflation.xlsx)
- [Data Dictionary](https://www.soa.org/globalassets/assets/files/research/opportunities/2026/student-research-case-study/srcsc-2026-data.pdf)
  
Additional CQMC-specific data was provided to inform our understanding of their exposure profile:
- [CQMC Inventory](https://www.soa.org/globalassets/assets/files/research/opportunities/2026/student-research-case-study/srcsc-2026-cosmic-quarry-inventory.xlsx)
- [CQMC Personnel](https://www.soa.org/globalassets/assets/files/research/opportunities/2026/student-research-case-study/srcsc-2026-cosmic-quarry-personnel.xlsx)
- [Online Encyclopedia Entry](https://www.soa.org/globalassets/assets/files/research/opportunities/2026/student-research-case-study/srcsc-2026-enc.pdf)

## Data Cleaning 
Before modelling, all four claim datasets were cleaned using a consistent validation process. Records with invalid categories, out-of-range values, or missing entries were removed if clearly invalid. Given limited visibility over how the raw data was collected, we adopted a conservative approach to preserve data integrity and reduce model bias. Example code snippet is below: 
```r
equip_freq <- equip_freq %>%
  clean_names() %>%
  
  # trim spaces in character columns
  mutate(across(where(is.character), str_trim)) %>%
  
  # turn any character entry containing ? into NA
  mutate(across(where(is.character), ~ifelse(grepl("\\?", .x), NA, .x))) %>%
  
  # turn blank character entries into NA
  mutate(across(where(is.character), ~na_if(.x, ""))) %>%
  
  # remove everything after underscore for remaining character values
  mutate(across(where(is.character), ~sub("_.*", "", .x))) %>%
  
  # remove rows with any NA
  drop_na() %>%
  
  # remove duplicates
  distinct() %>%
  
  # convert numeric fields
  mutate(
    equipment_age   = as.numeric(equipment_age),
    maintenance_int = as.numeric(maintenance_int),
    usage_int       = as.numeric(usage_int),
    exposure        = as.numeric(exposure),
    claim_count     = as.numeric(claim_count)
  ) %>%
  
  # keep only values within dictionary ranges
  filter(
    equipment_age >= 0 & equipment_age <= 10,
    maintenance_int >= 100 & maintenance_int <= 5000,
    usage_int >= 0 & usage_int <= 24,
    exposure > 0 & exposure <= 1,
    claim_count >= 0 & claim_count <= 3
  )
```

# Product Design
Our product design framework focuses on aligning coverage structure with the underlying risk profile of each hazard area. Across all products, key features such as deductibles, waiting periods, policy limits and risk-based pricing are used to reduce exposure to frequent, low-severity claims while maintaining protection against high-impact events. This ensures both pricing sustainability and effective risk transfer for CQMC.

<details>
<summary> The Galaxy General Equipment Failure Shield (EFS) </summary>
The Galaxy General Equipment Failure Shield (EFS) is an indemnity-based product covering sudden and unforeseen equipment breakdowns, designed for a low-frequency, high-severity risk profile where most units have no claims but a small number produce large losses. The product includes a Đ50,000 deductible to filter out minor attritional claims and a Đ400,000 per-occurrence policy limit to contain extreme tail losses while still covering most material events. Coverage excludes wear and tear, excessive usage, and inadequate maintenance, supporting stronger risk selection, capital protection, and pricing stability across different solar systems.
</details>
<details>
<summary> Interstellar Cargo Protection Policy (ICPP) </summary>
Interstellar Cargo Protection Policy (ICPP): Only insures cargo shipments damaged or obstructed due to high debris density on-route or extreme solar radiation exposure. Annual premiums charged depending on varying risk route rating. Staggered deductible rate from 5% - 10% for risk levels 1 - 5 reflects the proportional change in risk.

</details>
<details>
<summary> StellarCare Protection Plan (SCPP) </summary>
StellarCare Protection Plan (SCPP) provides indemnity cover for work-related injuries, including medical expenses, wage replacement and rehabilitation costs. The product includes a 21-day waiting period, a Đ5,000 deductible and a Đ30,000 policy limit to reduce high-frequency, low-severity claims while maintaining protection against more serious injuries. Rehabilitation support is included to reduce long-duration and psychological claims, while premiums are adjusted by occupation and solar system to reflect underlying risk differences.

</details>
<details>
<summary> Operational Continuity Cover (OCC) </summary>
Operational Continuity Cover (OCC): Provides partial indemnity cover that protects CQMC while keeping insurer exposure sustainable. The results show that, after applying the waiting period, deductible, coinsurance and policy limits, only 56.6% of losses remain payable, meaning the policy still covers meaningful interruption events while filtering out smaller losses. Although expected losses remain material, the tighter design reduces tail risk and lowers premiums, making the cover more affordable and insurable.
</details>

## Summary of Pricing & Capital Modelling 
- Equipment Failure: Aggregate losses were modelled using a compound frequency–severity approach, and the proposed EFS materially reduces retained loss through its deductible and policy limit structure. The gross portfolio premium is Đ141.4M, derived from an expected net loss of Đ108.8M, plus a 15% risk margin of Đ16.3M, 10% expense loading of Đ10.9M, and 5% profit margin of Đ5.4M, giving a per-unit rate of Đ6,171. Pricing is also differentiated by solar system to reflect underlying risk differences, with premium per exposure unit of Đ5,446 for Epsilon, Đ7,307 for Helionis Cluster, and Đ6,391 for Zeta, corresponding to portfolio premiums of Đ50.4M, Đ33.2M, and Đ58.4M, respectively.
  
- Cargo Loss: The cargo loss portfolio exhibits a bimodal severity distribution with significant tail risk driven by rare but catastrophic events. Expected losses are moderate (Đ3.77M), but extreme outcomes remain substantial (P99: Đ72.5M). The ICPP is financially sustainable, generating positive net revenue in both the short term (Đ0.71M) and long term (Đ0.80M) as costs and returns grow with inflation. The product reduces expected losses by ~33% and volatility by 44%, with strong protection against extreme losses (P99 ↓ 40%). Effectiveness increases under stress, with loss reductions rising to 42% and 53%, demonstrating robust tail-risk mitigation and pricing sustainability.
  
- Workers’ Compensation: The portfolio exhibits a high-frequency, moderate-severity profile with relatively stable loss patterns. Expected loss decreases from approximately Đ3.51M to Đ3.06M after product design, where deductibles and waiting periods are effective in reducing frequent claims.  Overall, the SCPP reduces volatility while maintaining adequate protection. However, capital requirements increase slightly due to concentration in more severe claims.

- Business Interruption: The selected OCC structure uses a 21-day waiting period, Đ150,000 deductible, 80% coinsurance and a Đ400,000 policy limit to reduce insurer liability while preserving cover for major interruption events. Before OCC, the simulated BI portfolio had an expected aggregate loss of Đ8.50 B, with tail losses reaching Đ8.66 B at the 95th percentile and Đ8.73 B at the 99th percentile. After OCC, the expected aggregate loss fell to Đ1.88 B, with clear reductions in both average and extreme losses. Stress testing also showed the cover remained effective under adverse scenarios, supporting affordability and lowering capital strain by concentrating protection on high-impact interruptions.


## Risk Assessment
The Helionis Cluster faces higher operational strain due to dense debris and unstable conditions, increasing the likelihood of cargo loss, equipment damage, worker injury, and business interruption. The Bayesia System is relatively more controlled, with stable routes reducing operational risk, although high solar radiation remains a key driver of severe losses. Oryn Delta is the most fragile, as navigation instability, low visibility, and communication limitations amplify failures across all hazard areas. Overall, Helionis and Oryn Delta present higher risk, while Bayesia is comparatively more resilient but still exposed to radiation-driven severity risk. 

## Threats Ranking 
| Rank | Threat | Impact | Mitigation |
| :--- | :--- | :--- | :--- |
| **1** | Catastrophic workplace incidents (e.g. machinery failures, major accidents) | Drives tail risk and capital strain by increasing p99 losses, creating multi-injury events, and raising aggregate losses and capital requirements. | Strengthen safety controls through preventive maintenance, monitoring, and incident planning. |
| **2** | Gravitational shear in asymmetric ring (Oryn Delta) | Causes equipment instability and structural stress, leading to severe breakdowns, operational disruption, and large correlated losses. | Apply tighter coverage terms, higher deductibles, and stricter risk selection in ring zones. |
| **3** | High asteroid debris density | Increases both claim frequency and severity by raising the likelihood of cargo losses and equipment failure. | Implement enhanced shielding requirements and stricter debris monitoring protocols, especially in Helionis. |
| **4** | High solar radiation exposure | Degrades cargo and increases severity risk for shielding-dependent systems. | Require stronger radiation shielding, hardened storage systems, and tighter operating limits. |
| **5** | Supply chain interruption | Increases claim frequency through delays in repair, replacement, and operations. | Diversify suppliers and maintain strong inventory buffers. |
| **6** | Insufficient energy backup capacity | Reduces system resilience and increases severity of operational disruptions. | Increase redundancy standards and backup capacity requirements. |



## Limitations
Historical loss drivers and claims data are assumed to be broadly representative of future interstellar operations, despite potential changes in environment and scale. Route risk classifications (1–5) are assumed to capture key drivers such as debris density, radiation exposure, and navigation complexity, and are used to adjust premiums. Pricing assumes constant expense (10%), risk (15%), and profit (5%) loadings across hazard areas. Stress testing parameters (e.g., λ × 0.75 for best case) are selected to reflect plausible operational changes. Inflation is approximated using a recent moving average, and limited data for Bayesia and Oryn Delta are supplemented by assuming similar behaviour to existing systems

## Data Limitations
Claims data are based on similar businesses, so future experience may differ due to changes in workforce, operations, and environmental conditions. Limited system-specific data for Bayesia and Oryn Delta introduces uncertainty in frequency and severity estimates. The use of Poisson and lognormal models may not fully capture extreme tail risks. Additionally, assumptions of independence and reliance on historical parameters (e.g., inflation, discount rates) may underestimate correlated risks and future loss volatility. 


> Be creative! You can embed or link your [data](player_data_salaries_2020.csv), [code](sample-data-clean.ipynb), and [images](ACC.png) here.

More information on GitHub Pages can be found [here](https://pages.github.com/).

![](Actuarial.gif)
