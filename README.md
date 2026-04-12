[![Review Assignment Due Date](https://classroom.github.com/assets/deadline-readme-button-22041afd0340ce965d47ae6ef1cefeee28c7c493a6346c4f15d667ab976d596c.svg)](https://classroom.github.com/a/FxAEmrI0)
# Actuarial Theory and Practice A

_"Tell me and I forget. Teach me and I remember. Involve me and I learn." – Benjamin Franklin_

---
Team Members: Lisa Cheng, Yi Yao Wang, Connie Gu, Deetya Jugnarain

### Project Overview
This project develops actuarial insurance solutions for Cosmic Quarry Mining Corporation (CQMC), focusing on pricing, risk assessment, and product design across its interstellar mining operations. The aim is to provide data-driven recommendations to Galaxy General Insurance Company on how to structure insurance products that effectively manage risk while maintaining profitability.

The analysis covers four key hazard areas, each representing a distinct source of operational risk:
- Equipment Failure: Low-frequency, high-severity breakdowns of specialised mining machinery, requiring protection against large, unexpected losses.
- Cargo Loss: Low-frequency and high severity events driven primarily by environmental hazards. Requires policy to protect policholders from catastrophic losses as CQMC expands its mining operatins and interstellar transportation networks. 
- Workers’ Compensation: 
- Business Interruption:

### Product Design

- Interstellar Cargo Protection Policy (ICPP): Only insures cargo shipments damaged or obstructed due to high debris density on-route or extreme solar radiation exposure. Annual premiums charged depending on varying risk route rating. Staggered deductible rate from 5% - 10% for risk levels 1 - 5 reflects the proportional change in risk. 

### Summary of Pricing & Capital Modelling 
- Cargo Loss: The cargo loss portfolio exhibits a bimodal severity distribution with significant tail risk driven by rare but catastrophic events. Expected losses are moderate (Đ3.77M), but extreme outcomes remain substantial (P99: Đ72.5M). The ICPP is financially sustainable, generating positive net revenue in both the short term (Đ0.71M) and long term (Đ0.80M) as costs and returns grow with inflation. The product reduces expected losses by ~33% and volatility by 44%, with strong protection against extreme losses (P99 ↓ 40%). Effectiveness increases under stress, with loss reductions rising to 42% and 53%, demonstrating robust tail-risk mitigation and pricing sustainability.

### Risk Assessment
The Helionis Cluster faces higher operational strain due to dense debris and unstable conditions, increasing the likelihood of cargo loss, equipment damage, worker injury, and business interruption. The Bayesia System is relatively more controlled, with stable routes reducing operational risk, although high solar radiation remains a key driver of severe losses. Oryn Delta is the most fragile, as navigation instability, low visibility, and communication limitations amplify failures across all hazard areas. Overall, Helionis and Oryn Delta present higher risk, while Bayesia is comparatively more resilient but still exposed to radiation-driven severity risk.

### Limitations
Historical loss drivers and claims data are assumed to be broadly representative of future interstellar operations, despite potential changes in environment and scale. Route risk classifications (1–5) are assumed to capture key drivers such as debris density, radiation exposure, and navigation complexity, and are used to adjust premiums. Pricing assumes constant expense (10%), risk (15%), and profit (5%) loadings across hazard areas. Stress testing parameters (e.g., λ × 0.75 for best case) are selected to reflect plausible operational changes. Inflation is approximated using a recent moving average, and limited data for Bayesia and Oryn Delta are supplemented by assuming similar behaviour to existing systems

### Data Limitations
Claims data are based on similar businesses, so future experience may differ due to changes in workforce, operations, and environmental conditions. Limited system-specific data for Bayesia and Oryn Delta introduces uncertainty in frequency and severity estimates. The use of Poisson and lognormal models may not fully capture extreme tail risks. Additionally, assumptions of independence and reliance on historical parameters (e.g., inflation, discount rates) may underestimate correlated risks and future loss volatility. 

This page is written in Markdown.
- Click the [assignment link](https://classroom.github.com/a/FxAEmrI0) to accept your assignment.

---

> Be creative! You can embed or link your [data](player_data_salaries_2020.csv), [code](sample-data-clean.ipynb), and [images](ACC.png) here.

More information on GitHub Pages can be found [here](https://pages.github.com/).

![](Actuarial.gif)
