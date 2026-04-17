# =========================================================
# ACTL4001 - Equipment Failure Analysis
# ---------------------------------------------------------
# This script combines and streamlines the following tasks:
# 1. Data loading and cleaning
# 2. Exploratory data analysis
# 3. Pricing and premium derivation
# 4. Aggregate loss modelling
# 5. Stress testing before and after product design
# 6. Solar-system comparison
# 7. Scenario testing
# =========================================================

# -----------------------------
# 0. Packages
# -----------------------------
suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(janitor)
  library(stringr)
  library(ggplot2)
  library(scales)
})

# -----------------------------
# 1. File paths
# -----------------------------
claims_file <- "srcsc-2026-claims-equipment-failure.xlsx"
inflation_file <- "srcsc-2026-interest-and-inflation.xlsx"

# Optional fallback for local folders outside this working directory
if (!file.exists(claims_file)) {
  stop("Equipment failure claims file not found in working directory. Update `claims_file` path.")
}

if (!file.exists(inflation_file)) {
  stop("Interest and inflation file not found in working directory. Update `inflation_file` path.")
}

# -----------------------------
# 2. Load raw data
# -----------------------------
equip_freq_raw <- read_excel(claims_file, sheet = "freq")
equip_sev_raw  <- read_excel(claims_file, sheet = "sev")

# -----------------------------
# 3. Cleaning function
# -----------------------------
clean_character_fields <- function(df) {
  df %>%
    clean_names() %>%
    mutate(across(where(is.character), str_trim)) %>%
    mutate(across(where(is.character), ~ ifelse(grepl("\\?", .x), NA, .x))) %>%
    mutate(across(where(is.character), ~ na_if(.x, ""))) %>%
    mutate(across(where(is.character), ~ sub("_.*", "", .x))) %>%
    distinct() %>%
    drop_na()
}

# -----------------------------
# 4. Clean frequency and severity data
# -----------------------------
equip_freq <- clean_character_fields(equip_freq_raw) %>%
  mutate(
    equipment_age   = as.numeric(equipment_age),
    maintenance_int = as.numeric(maintenance_int),
    usage_int       = as.numeric(usage_int),
    exposure        = as.numeric(exposure),
    claim_count     = as.numeric(claim_count)
  ) %>%
  filter(
    equipment_age >= 0 & equipment_age <= 10,
    maintenance_int >= 100 & maintenance_int <= 5000,
    usage_int >= 0 & usage_int <= 24,
    exposure > 0 & exposure <= 1,
    claim_count >= 0 & claim_count <= 3
  )

equip_sev <- clean_character_fields(equip_sev_raw) %>%
  mutate(
    equipment_age   = as.numeric(equipment_age),
    maintenance_int = as.numeric(maintenance_int),
    usage_int       = as.numeric(usage_int),
    exposure        = as.numeric(exposure),
    claim_amount    = as.numeric(claim_amount),
    claim_seq       = as.numeric(claim_seq)
  ) %>%
  filter(
    equipment_age >= 0 & equipment_age <= 10,
    maintenance_int >= 100 & maintenance_int <= 5000,
    usage_int >= 0 & usage_int <= 24,
    exposure > 0 & exposure <= 1,
    claim_amount >= 11000 & claim_amount <= 790000,
    claim_seq >= 1 & claim_seq <= 3
  ) %>%
  mutate(solar_system = trimws(solar_system))

equip_freq <- equip_freq %>%
  mutate(solar_system = trimws(solar_system))

solar_systems <- sort(unique(equip_freq$solar_system))

# -----------------------------
# 5. Product and pricing assumptions
# -----------------------------
deductible <- 50000
expense_loading_pct <- 0.10
risk_margin_pct     <- 0.15
profit_margin_pct   <- 0.05
loading_factor <- 1 + expense_loading_pct + risk_margin_pct + profit_margin_pct
n_sim <- 10000

# -----------------------------
# 6. Inflation assumption
#    3-year moving average
# -----------------------------
infl <- read_excel(inflation_file, skip = 3, col_names = FALSE)
colnames(infl) <- c("year", "inflation", "overnight_rate", "spot_1y", "spot_10y")

infl <- infl %>%
  mutate(across(everything(), as.numeric))

infl_ma_3yr <- mean(tail(infl$inflation, 3), na.rm = TRUE)
infl_factor <- 1 + infl_ma_3yr

# -----------------------------
# 7. Portfolio-level EDA
# -----------------------------
total_exposure <- sum(equip_freq$exposure, na.rm = TRUE)
total_claims   <- sum(equip_freq$claim_count, na.rm = TRUE)
total_loss     <- sum(equip_sev$claim_amount, na.rm = TRUE)

portfolio_metrics <- tibble(
  metric = c(
    "Total exposure",
    "Total claims",
    "Total loss",
    "Claim frequency rate",
    "Average severity",
    "Loss cost per exposure",
    "Maximum claim amount",
    "Standard deviation of claim amount"
  ),
  value = c(
    total_exposure,
    total_claims,
    total_loss,
    total_claims / total_exposure,
    total_loss / total_claims,
    total_loss / total_exposure,
    max(equip_sev$claim_amount, na.rm = TRUE),
    sd(equip_sev$claim_amount, na.rm = TRUE)
  )
)

unique_table <- bind_rows(
  equip_freq %>%
    summarise(across(where(~ is.character(.x) || is.factor(.x)), ~ n_distinct(.))) %>%
    pivot_longer(everything(), names_to = "variable", values_to = "n_unique") %>%
    mutate(dataset = "equip_freq"),
  equip_sev %>%
    summarise(across(where(~ is.character(.x) || is.factor(.x)), ~ n_distinct(.))) %>%
    pivot_longer(everything(), names_to = "variable", values_to = "n_unique") %>%
    mutate(dataset = "equip_sev")
) %>%
  select(dataset, variable, n_unique)

numeric_summary <- bind_rows(
  equip_freq %>%
    summarise(across(where(is.numeric),
      list(
        min = ~ min(., na.rm = TRUE),
        q1 = ~ quantile(., 0.25, na.rm = TRUE),
        median = ~ median(., na.rm = TRUE),
        mean = ~ mean(., na.rm = TRUE),
        q3 = ~ quantile(., 0.75, na.rm = TRUE),
        max = ~ max(., na.rm = TRUE),
        sd = ~ sd(., na.rm = TRUE)
      ),
      .names = "{.col}_{.fn}"
    )) %>%
    pivot_longer(everything(), names_to = c("variable", "stat"), names_sep = "_(?=[^_]+$)", values_to = "value") %>%
    pivot_wider(names_from = stat, values_from = value) %>%
    mutate(dataset = "equip_freq"),
  equip_sev %>%
    summarise(across(where(is.numeric),
      list(
        min = ~ min(., na.rm = TRUE),
        q1 = ~ quantile(., 0.25, na.rm = TRUE),
        median = ~ median(., na.rm = TRUE),
        mean = ~ mean(., na.rm = TRUE),
        q3 = ~ quantile(., 0.75, na.rm = TRUE),
        max = ~ max(., na.rm = TRUE),
        sd = ~ sd(., na.rm = TRUE)
      ),
      .names = "{.col}_{.fn}"
    )) %>%
    pivot_longer(everything(), names_to = c("variable", "stat"), names_sep = "_(?=[^_]+$)", values_to = "value") %>%
    pivot_wider(names_from = stat, values_from = value) %>%
    mutate(dataset = "equip_sev")
) %>%
  select(dataset, variable, min, q1, median, mean, q3, max, sd)

claim_count_table <- equip_freq %>%
  count(claim_count) %>%
  mutate(prop = n / sum(n))

tail_claims_table <- tibble(
  percentile_95  = quantile(equip_sev$claim_amount, 0.95, na.rm = TRUE),
  percentile_99  = quantile(equip_sev$claim_amount, 0.99, na.rm = TRUE),
  percentile_999 = quantile(equip_sev$claim_amount, 0.999, na.rm = TRUE),
  max_claim      = max(equip_sev$claim_amount, na.rm = TRUE)
)

top_10_claims <- equip_sev %>%
  arrange(desc(claim_amount)) %>%
  slice_head(n = 10)

freq_dist <- equip_freq %>%
  count(claim_count) %>%
  mutate(
    pct = n / sum(n),
    pct_label = percent(pct, accuracy = 0.1)
  )

freq_by_system <- equip_freq %>%
  group_by(solar_system) %>%
  summarise(
    exposure = sum(exposure, na.rm = TRUE),
    claims = sum(claim_count, na.rm = TRUE),
    claim_frequency = claims / exposure,
    mean_claims = mean(claim_count, na.rm = TRUE),
    sd_claims = sd(claim_count, na.rm = TRUE),
    .groups = "drop"
  )

sev_by_system <- equip_sev %>%
  group_by(solar_system) %>%
  summarise(
    mean_severity = mean(claim_amount, na.rm = TRUE),
    sd_severity = sd(claim_amount, na.rm = TRUE),
    max_loss = max(claim_amount, na.rm = TRUE),
    total_loss = sum(claim_amount, na.rm = TRUE),
    .groups = "drop"
  )

loss_by_system <- freq_by_system %>%
  left_join(sev_by_system, by = "solar_system") %>%
  mutate(loss_cost = total_loss / exposure)

# -----------------------------
# 8. Optional GLMs
# -----------------------------
freq_model <- glm(
  claim_count ~ equipment_age + maintenance_int + usage_int + solar_system + equipment_type,
  family = poisson(),
  offset = log(exposure),
  data = equip_freq
)

sev_model <- glm(
  claim_amount ~ equipment_age + maintenance_int + usage_int + solar_system + equipment_type,
  family = Gamma(link = "log"),
  data = equip_sev
)

# -----------------------------
# 9. Pricing - portfolio level
# -----------------------------
lambda_hat <- total_claims / total_exposure

net_mean_claim <- mean(
  pmax(equip_sev$claim_amount * infl_factor - deductible, 0),
  na.rm = TRUE
)

expected_net_loss <- total_exposure * lambda_hat * net_mean_claim
risk_margin      <- expected_net_loss * risk_margin_pct
expense_loading  <- expected_net_loss * expense_loading_pct
profit_margin    <- expected_net_loss * profit_margin_pct
portfolio_premium <- expected_net_loss + risk_margin + expense_loading + profit_margin
premium_per_exposure <- portfolio_premium / total_exposure

pricing_summary <- tibble(
  total_claims = total_claims,
  total_exposure = total_exposure,
  lambda_hat = lambda_hat,
  inflation_ma_3yr = infl_ma_3yr,
  deductible = deductible,
  net_mean_claim = net_mean_claim,
  expected_net_loss = expected_net_loss,
  risk_margin = risk_margin,
  expense_loading = expense_loading,
  profit_margin = profit_margin,
  portfolio_premium = portfolio_premium,
  premium_per_exposure = premium_per_exposure
)

# -----------------------------
# 10. Pricing - by solar system
# -----------------------------
sev_summary_by_system <- equip_sev %>%
  mutate(
    inflated = claim_amount * infl_factor,
    net = pmax(inflated - deductible, 0)
  ) %>%
  group_by(solar_system) %>%
  summarise(
    median = median(claim_amount, na.rm = TRUE),
    q25 = quantile(claim_amount, 0.25, na.rm = TRUE),
    q75 = quantile(claim_amount, 0.75, na.rm = TRUE),
    gross_mean = mean(inflated, na.rm = TRUE),
    net_mean = mean(net, na.rm = TRUE),
    pct_removed = mean(net == 0, na.rm = TRUE),
    .groups = "drop"
  )

pricing_by_system <- equip_freq %>%
  group_by(solar_system) %>%
  summarise(
    total_claims = sum(claim_count, na.rm = TRUE),
    total_exp = sum(exposure, na.rm = TRUE),
    lambda = total_claims / total_exp,
    .groups = "drop"
  ) %>%
  left_join(sev_summary_by_system, by = "solar_system") %>%
  mutate(
    deductible = deductible,
    pure_prem = lambda * net_mean,
    prem_per_exp = pure_prem * loading_factor,
    portfolio_prem = total_exp * prem_per_exp
  )

total_row <- pricing_by_system %>%
  summarise(
    solar_system = "Total",
    total_claims = sum(total_claims, na.rm = TRUE),
    total_exp = sum(total_exp, na.rm = TRUE),
    lambda = sum(total_claims, na.rm = TRUE) / sum(total_exp, na.rm = TRUE),
    median = NA_real_,
    q25 = NA_real_,
    q75 = NA_real_,
    gross_mean = NA_real_,
    net_mean = NA_real_,
    pct_removed = NA_real_,
    deductible = deductible,
    pure_prem = sum(pure_prem * total_exp, na.rm = TRUE) / sum(total_exp, na.rm = TRUE),
    prem_per_exp = sum(prem_per_exp * total_exp, na.rm = TRUE) / sum(total_exp, na.rm = TRUE),
    portfolio_prem = sum(portfolio_prem, na.rm = TRUE)
  )

pricing_by_system_final <- bind_rows(pricing_by_system, total_row)

# -----------------------------
# 11. Aggregate loss modelling
# -----------------------------
portfolio_exposure <- total_exposure
expected_N <- lambda_hat * portfolio_exposure
meanlog_hat <- mean(log(equip_sev$claim_amount), na.rm = TRUE)
sdlog_hat   <- sd(log(equip_sev$claim_amount), na.rm = TRUE)

set.seed(123)
agg_losses <- numeric(n_sim)
for (i in seq_len(n_sim)) {
  N_i <- rpois(1, lambda = expected_N)
  if (N_i > 0) {
    claims_i <- rlnorm(N_i, meanlog = meanlog_hat, sdlog = sdlog_hat)
    agg_losses[i] <- sum(claims_i)
  }
}

agg_summary <- tibble(
  mean = mean(agg_losses),
  variance = var(agg_losses),
  sd = sd(agg_losses),
  p95 = quantile(agg_losses, 0.95),
  p99 = quantile(agg_losses, 0.99),
  max = max(agg_losses)
)

# -----------------------------
# 12. Aggregate loss by solar system
# -----------------------------
agg_results <- list()
agg_summary_by_system <- tibble()

for (sys in solar_systems) {
  freq_sys <- equip_freq %>% filter(solar_system == sys)
  sev_sys  <- equip_sev %>% filter(solar_system == sys)

  sys_lambda_hat <- sum(freq_sys$claim_count, na.rm = TRUE) / sum(freq_sys$exposure, na.rm = TRUE)
  sys_exposure   <- sum(freq_sys$exposure, na.rm = TRUE)
  sys_expected_N <- sys_lambda_hat * sys_exposure
  sys_meanlog    <- mean(log(sev_sys$claim_amount), na.rm = TRUE)
  sys_sdlog      <- sd(log(sev_sys$claim_amount), na.rm = TRUE)

  sys_losses <- numeric(n_sim)
  for (i in seq_len(n_sim)) {
    N_i <- rpois(1, lambda = sys_expected_N)
    if (N_i > 0) {
      claims_i <- rlnorm(N_i, meanlog = sys_meanlog, sdlog = sys_sdlog)
      sys_losses[i] <- sum(claims_i)
    }
  }

  agg_results[[sys]] <- sys_losses

  agg_summary_by_system <- bind_rows(
    agg_summary_by_system,
    tibble(
      solar_system = sys,
      expected_claim_count = sys_expected_N,
      mean = mean(sys_losses),
      variance = var(sys_losses),
      sd = sd(sys_losses),
      p50 = quantile(sys_losses, 0.50),
      p75 = quantile(sys_losses, 0.75),
      p90 = quantile(sys_losses, 0.90),
      p95 = quantile(sys_losses, 0.95),
      p99 = quantile(sys_losses, 0.99),
      max = max(sys_losses)
    )
  )
}

# -----------------------------
# 13. Stress testing before and after product
# -----------------------------
simulate_aggregate <- function(expected_N,
                               meanlog_hat,
                               sdlog_hat,
                               freq_multiplier = 1,
                               sev_multiplier = 1,
                               deductible = 0,
                               n_sim = 10000) {
  agg <- numeric(n_sim)

  for (i in seq_len(n_sim)) {
    N_i <- rpois(1, lambda = expected_N * freq_multiplier)

    if (N_i > 0) {
      claims_i <- rlnorm(
        N_i,
        meanlog = meanlog_hat + log(sev_multiplier),
        sdlog = sdlog_hat
      )
      agg[i] <- sum(pmax(claims_i - deductible, 0))
    }
  }

  agg
}

base_before <- simulate_aggregate(expected_N, meanlog_hat, sdlog_hat, deductible = 0, n_sim = n_sim)
moderate_before <- simulate_aggregate(expected_N, meanlog_hat, sdlog_hat, freq_multiplier = 1.2, sev_multiplier = 1.25, deductible = 0, n_sim = n_sim)
extreme_before <- simulate_aggregate(expected_N, meanlog_hat, sdlog_hat, freq_multiplier = 1.5, sev_multiplier = 1.75, deductible = 0, n_sim = n_sim)

base_after <- simulate_aggregate(expected_N, meanlog_hat, sdlog_hat, deductible = deductible, n_sim = n_sim)
moderate_after <- simulate_aggregate(expected_N, meanlog_hat, sdlog_hat, freq_multiplier = 1.2, sev_multiplier = 1.25, deductible = deductible, n_sim = n_sim)
extreme_after <- simulate_aggregate(expected_N, meanlog_hat, sdlog_hat, freq_multiplier = 1.5, sev_multiplier = 1.75, deductible = deductible, n_sim = n_sim)

comparison_stress <- bind_rows(
  tibble(basis = "Before Product", scenario = "Base", mean = mean(base_before), p95 = quantile(base_before, 0.95), p99 = quantile(base_before, 0.99)),
  tibble(basis = "Before Product", scenario = "Moderate Stress", mean = mean(moderate_before), p95 = quantile(moderate_before, 0.95), p99 = quantile(moderate_before, 0.99)),
  tibble(basis = "Before Product", scenario = "Extreme Stress", mean = mean(extreme_before), p95 = quantile(extreme_before, 0.95), p99 = quantile(extreme_before, 0.99)),
  tibble(basis = "After Product", scenario = "Base", mean = mean(base_after), p95 = quantile(base_after, 0.95), p99 = quantile(base_after, 0.99)),
  tibble(basis = "After Product", scenario = "Moderate Stress", mean = mean(moderate_after), p95 = quantile(moderate_after, 0.95), p99 = quantile(moderate_after, 0.99)),
  tibble(basis = "After Product", scenario = "Extreme Stress", mean = mean(extreme_after), p95 = quantile(extreme_after, 0.95), p99 = quantile(extreme_after, 0.99))
)

# -----------------------------
# 14. Before/after comparison by solar system
# -----------------------------
comparison_by_system <- tibble()

for (sys in solar_systems) {
  freq_sys <- equip_freq %>% filter(solar_system == sys)
  sev_sys  <- equip_sev %>% filter(solar_system == sys)

  sys_lambda_hat <- sum(freq_sys$claim_count, na.rm = TRUE) / sum(freq_sys$exposure, na.rm = TRUE)
  sys_exposure   <- sum(freq_sys$exposure, na.rm = TRUE)
  sys_expected_N <- sys_lambda_hat * sys_exposure
  sys_meanlog    <- mean(log(sev_sys$claim_amount), na.rm = TRUE)
  sys_sdlog      <- sd(log(sev_sys$claim_amount), na.rm = TRUE)

  sys_net_mean_claim <- mean(pmax(sev_sys$claim_amount * infl_factor - deductible, 0), na.rm = TRUE)
  sys_pure_prem <- sys_lambda_hat * sys_net_mean_claim
  sys_premium_per_exposure <- sys_pure_prem * loading_factor
  sys_portfolio_premium <- sys_exposure * sys_premium_per_exposure

  gross_losses <- numeric(n_sim)
  net_losses <- numeric(n_sim)
  retained_losses <- numeric(n_sim)
  insurer_profit <- numeric(n_sim)

  for (i in seq_len(n_sim)) {
    N_i <- rpois(1, lambda = sys_expected_N)

    if (N_i > 0) {
      gross_claims <- rlnorm(N_i, meanlog = sys_meanlog, sdlog = sys_sdlog) * infl_factor
      gross_losses[i] <- sum(gross_claims)

      net_claims <- pmax(gross_claims - deductible, 0)
      retained_claims <- pmin(gross_claims, deductible)

      net_losses[i] <- sum(net_claims)
      retained_losses[i] <- sum(retained_claims)
    }

    insurer_profit[i] <- sys_portfolio_premium - net_losses[i]
  }

  comparison_by_system <- bind_rows(
    comparison_by_system,
    tibble(
      solar_system = sys,
      expected_claim_count = sys_expected_N,
      gross_mean = mean(gross_losses),
      gross_p95 = quantile(gross_losses, 0.95),
      gross_p99 = quantile(gross_losses, 0.99),
      net_mean = mean(net_losses),
      net_p95 = quantile(net_losses, 0.95),
      net_p99 = quantile(net_losses, 0.99),
      company_retained_mean = mean(retained_losses),
      expected_loss_reduction = mean(gross_losses) - mean(net_losses),
      reduction_pct = (mean(gross_losses) - mean(net_losses)) / mean(gross_losses) * 100,
      portfolio_premium = sys_portfolio_premium,
      expected_insurer_profit = mean(insurer_profit),
      profit_margin_pct = mean(insurer_profit) / sys_portfolio_premium * 100,
      return_on_cost = mean(insurer_profit) / mean(net_losses)
    )
  )
}

# -----------------------------
# 15. Scenario testing
# -----------------------------
param_by_system <- tibble()
for (sys in solar_systems) {
  freq_sys <- equip_freq %>% filter(solar_system == sys)
  sev_sys  <- equip_sev %>% filter(solar_system == sys)

  param_by_system <- bind_rows(
    param_by_system,
    tibble(
      solar_system = sys,
      lambda_hat = sum(freq_sys$claim_count, na.rm = TRUE) / sum(freq_sys$exposure, na.rm = TRUE),
      exposure = sum(freq_sys$exposure, na.rm = TRUE),
      meanlog_hat = mean(log(sev_sys$claim_amount), na.rm = TRUE),
      sdlog_hat = sd(log(sev_sys$claim_amount), na.rm = TRUE)
    )
  )
}

simulate_scenario <- function(param_by_system,
                              scenario = c("best", "moderate", "worst"),
                              isolated_system = "Zeta",
                              deductible = 50000,
                              n_sim = 10000) {
  scenario <- match.arg(scenario)
  agg_losses <- numeric(n_sim)

  for (i in seq_len(n_sim)) {
    total_loss <- 0

    for (j in seq_len(nrow(param_by_system))) {
      sys <- param_by_system$solar_system[j]
      sys_lambda_hat <- param_by_system$lambda_hat[j]
      sys_exposure   <- param_by_system$exposure[j]
      sys_meanlog    <- param_by_system$meanlog_hat[j]
      sys_sdlog      <- param_by_system$sdlog_hat[j]

      freq_mult <- 1
      sev_mult  <- 1

      if (scenario == "best") {
        freq_mult <- 0.75
        sev_mult <- 1.00
      }

      if (scenario == "moderate") {
        if (sys == isolated_system) {
          freq_mult <- 1.15
          sev_mult <- 1.20
        }
      }

      if (scenario == "worst") {
        freq_mult <- 2.00
        sev_mult <- 1.50
      }

      sys_expected_N <- sys_lambda_hat * sys_exposure * freq_mult
      N_i <- rpois(1, lambda = sys_expected_N)

      if (N_i > 0) {
        gross_claims <- rlnorm(
          N_i,
          meanlog = sys_meanlog + log(sev_mult),
          sdlog = sys_sdlog
        )
        total_loss <- total_loss + sum(pmax(gross_claims - deductible, 0))
      }
    }

    agg_losses[i] <- total_loss
  }

  agg_losses
}

isolated_system <- "Zeta"
set.seed(123)
best_case <- simulate_scenario(param_by_system, scenario = "best", isolated_system = isolated_system, deductible = deductible, n_sim = n_sim)
moderate_case <- simulate_scenario(param_by_system, scenario = "moderate", isolated_system = isolated_system, deductible = deductible, n_sim = n_sim)
worst_case <- simulate_scenario(param_by_system, scenario = "worst", isolated_system = isolated_system, deductible = deductible, n_sim = n_sim)

scenario_table <- bind_rows(
  tibble(Scenario = "Best case", Description = "Smooth operations, attritional only", Mean = mean(best_case), Variance = var(best_case), SD = sd(best_case), P95 = quantile(best_case, 0.95), P99 = quantile(best_case, 0.99), Max = max(best_case)),
  tibble(Scenario = "Moderate case", Description = paste0("Isolated system event (", isolated_system, " only)"), Mean = mean(moderate_case), Variance = var(moderate_case), SD = sd(moderate_case), P95 = quantile(moderate_case, 0.95), P99 = quantile(moderate_case, 0.99), Max = max(moderate_case)),
  tibble(Scenario = "Worst case", Description = "Catastrophic correlated multi-system failure", Mean = mean(worst_case), Variance = var(worst_case), SD = sd(worst_case), P95 = quantile(worst_case, 0.95), P99 = quantile(worst_case, 0.99), Max = max(worst_case))
) %>%
  mutate(across(where(is.numeric), ~ round(.x, 2)))

# -----------------------------
# 16. Example plots
# -----------------------------
claim_count_plot <- ggplot(freq_dist, aes(x = factor(claim_count), y = pct)) +
  geom_col() +
  geom_text(aes(label = pct_label), vjust = -0.3, size = 4) +
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  labs(
    title = "Equipment Failure Claim Count Distribution",
    x = "Number of Claims per Exposure Unit",
    y = "Proportion of Units"
  ) +
  theme_minimal()

after_product_hist <- ggplot(data.frame(loss = base_after), aes(x = loss)) +
  geom_histogram(bins = 50, fill = "steelblue", color = "black", alpha = 0.8) +
  labs(
    title = "Aggregate Loss Distribution (After Product)",
    x = "Aggregate Loss",
    y = "Frequency"
  ) +
  theme_minimal()

# -----------------------------
# 17. Key outputs to inspect
# -----------------------------
print(portfolio_metrics)
print(unique_table)
print(numeric_summary)
print(claim_count_table)
print(tail_claims_table)
print(top_10_claims)
print(loss_by_system)
print(summary(freq_model))
print(summary(sev_model))
print(round(pricing_summary, 2))
print(pricing_by_system_final %>% mutate(across(where(is.numeric), ~ round(.x, 2))))
print(round(agg_summary, 2))
print(agg_summary_by_system %>% mutate(across(where(is.numeric), ~ round(.x, 2))))
print(comparison_stress %>% mutate(across(where(is.numeric), ~ round(.x, 2))))
print(comparison_by_system %>% mutate(across(where(is.numeric), ~ round(.x, 2))))
print(scenario_table)

# To display plots in an interactive R session, run:
# claim_count_plot
# after_product_hist
