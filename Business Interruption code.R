library(readxl)
library(dplyr)
library(stringr)
library(janitor)
library(tidyr)

file_path <- "~/Downloads/SOA_2026_Case_Study_Materials 2/srcsc-2026-claims-business-interruption.xlsx"

# ----------------------------
# 1) Import both sheets
# ----------------------------
bi_freq_raw <- read_excel(file_path, sheet = "freq") %>%
  clean_names()

bi_sev_raw <- read_excel(file_path, sheet = "sev") %>%
  clean_names()

# ----------------------------
# 2) Set allowed category levels
# ----------------------------
solar_levels <- c("Helionis Cluster", "Epsilon", "Zeta")
score_levels <- c("1", "2", "3", "4", "5")

# ----------------------------
# 3) Helper function to clean text fields
# ----------------------------
clean_text <- function(x) {
  x %>%
    as.character() %>%
    str_trim() %>%
    na_if("") %>%
    na_if("?") %>%
    na_if("NA") %>%
    na_if("N/A")
}

# remove suffix after underscore if present
remove_suffix <- function(x) {
  ifelse(is.na(x), NA, str_remove(x, "_.*$"))
}

# ----------------------------
# 4) Clean frequency sheet
# Dictionary ranges:
# production_load: 0–1
# energy_backup_score: {1,2,3,4,5}
# supply_chain_index: 0–1
# avg_crew_exp: 1–30
# maintenance_freq: 0–6
# safety_compliance: {1,2,3,4,5}
# exposure: 0–1
# claim_count: 0–4
# ----------------------------
bi_freq <- bi_freq_raw %>%
  mutate(across(where(is.character), clean_text)) %>%
  mutate(
    policy_id      = remove_suffix(policy_id),
    station_id     = remove_suffix(station_id),
    solar_system   = remove_suffix(solar_system),
    
    production_load     = as.numeric(production_load),
    energy_backup_score = as.numeric(energy_backup_score),
    supply_chain_index  = as.numeric(supply_chain_index),
    avg_crew_exp        = as.numeric(avg_crew_exp),
    maintenance_freq    = as.numeric(maintenance_freq),
    safety_compliance   = as.numeric(safety_compliance),
    exposure            = as.numeric(exposure),
    claim_count         = as.numeric(claim_count)
  ) %>%
  filter(
    !is.na(policy_id),
    !is.na(station_id),
    !is.na(solar_system),
    solar_system %in% solar_levels,
    
    !is.na(production_load)     & between(production_load, 0, 1),
    !is.na(energy_backup_score) & energy_backup_score %in% 1:5,
    !is.na(supply_chain_index)  & between(supply_chain_index, 0, 1),
    !is.na(avg_crew_exp)        & between(avg_crew_exp, 1, 30),
    !is.na(maintenance_freq)    & between(maintenance_freq, 0, 6),
    !is.na(safety_compliance)   & safety_compliance %in% 1:5,
    !is.na(exposure)            & between(exposure, 0, 1),
    !is.na(claim_count)         & claim_count %in% 0:4,
    claim_count == floor(claim_count)
  ) %>%
  mutate(
    solar_system        = factor(solar_system, levels = solar_levels),
    energy_backup_score = factor(as.character(energy_backup_score), levels = score_levels),
    safety_compliance   = factor(as.character(safety_compliance), levels = score_levels),
    claim_count         = as.integer(claim_count)
  ) %>%
  distinct()

# ----------------------------
# 5) Clean severity sheet
# Dictionary ranges/levels:
# production_load: 0–1
# exposure: 0–1
# energy_backup_score: {1,2,3,4,5}
# safety_compliance: {1,2,3,4,5}
# claim_amount: 28,000–1,426,000
# claim_seq: positive whole number
# ----------------------------
bi_sev <- bi_sev_raw %>%
  mutate(across(where(is.character), clean_text)) %>%
  mutate(
    claim_id      = remove_suffix(claim_id),
    policy_id     = remove_suffix(policy_id),
    station_id    = remove_suffix(station_id),
    solar_system  = remove_suffix(solar_system),
    
    claim_seq            = as.numeric(claim_seq),
    production_load      = as.numeric(production_load),
    exposure             = as.numeric(exposure),
    energy_backup_score  = as.numeric(energy_backup_score),
    safety_compliance    = as.numeric(safety_compliance),
    claim_amount         = as.numeric(claim_amount)
  ) %>%
  filter(
    !is.na(claim_id),
    !is.na(policy_id),
    !is.na(station_id),
    !is.na(solar_system),
    solar_system %in% solar_levels,
    
    !is.na(claim_seq)           & claim_seq >= 1,
    claim_seq == floor(claim_seq),
    
    !is.na(production_load)     & between(production_load, 0, 1),
    !is.na(exposure)            & between(exposure, 0, 1),
    !is.na(energy_backup_score) & energy_backup_score %in% 1:5,
    !is.na(safety_compliance)   & safety_compliance %in% 1:5,
    !is.na(claim_amount)        & between(claim_amount, 28000, 1426000)
  ) %>%
  mutate(
    solar_system        = factor(solar_system, levels = solar_levels),
    energy_backup_score = factor(as.character(energy_backup_score), levels = score_levels),
    safety_compliance   = factor(as.character(safety_compliance), levels = score_levels),
    claim_seq           = as.integer(claim_seq)
  ) %>%
  distinct()

# ----------------------------
# 6) Quick cleaning summary
# ----------------------------
cat("Frequency rows before:", nrow(bi_freq_raw), "\n")
cat("Frequency rows after :", nrow(bi_freq), "\n\n")

cat("Severity rows before :", nrow(bi_sev_raw), "\n")
cat("Severity rows after  :", nrow(bi_sev), "\n\n")

# ----------------------------
# 7) Quick checks
# ----------------------------
glimpse(bi_freq)
glimpse(bi_sev)

summary(bi_freq)
summary(bi_sev)

# frequency dispersion check
mean_claims <- mean(bi_freq$claim_count)
var_claims  <- var(bi_freq$claim_count)

cat("Mean claim count:", mean_claims, "\n")
cat("Variance claim count:", var_claims, "\n")







library(MASS)

# ----------------------------
# Fit severity distribution
# ----------------------------

sev_fit <- fitdistr(bi_sev$claim_amount, "lognormal")

# extract parameters
meanlog_hat <- sev_fit$estimate["meanlog"]
sdlog_hat   <- sev_fit$estimate["sdlog"]

# show fitted distribution
sev_fit
cat("meanlog =", meanlog_hat, "\n")
cat("sdlog   =", sdlog_hat, "\n")
# observed claim severity statistics
mean_sev <- mean(bi_sev$claim_amount)
sd_sev   <- sd(bi_sev$claim_amount)

quantiles <- quantile(
  bi_sev$claim_amount,
  c(0.50, 0.75, 0.90, 0.95, 0.99)
)

mean_sev
sd_sev
quantiles
hist(
  bi_sev$claim_amount,
  breaks = 40,
  main = "Observed Claim Severity Distribution",
  xlab = "Claim Amount",
  col = "lightblue"
)







library(dplyr)

# -----------------------------
# 1. Check the raw inputs first
# -----------------------------
total_claims <- sum(bi_freq$claim_count, na.rm = TRUE)
total_exposure <- sum(bi_freq$exposure, na.rm = TRUE)

lambda_hat <- total_claims / total_exposure   # claims per exposure unit

mean_sev <- mean(bi_sev$claim_amount, na.rm = TRUE)

total_claims
total_exposure
lambda_hat
mean_sev
lambda_hat * total_exposure   # expected portfolio claim count

# -----------------------------
# 2. Fit simple severity model
# -----------------------------
meanlog_hat <- mean(log(bi_sev$claim_amount), na.rm = TRUE)
sdlog_hat   <- sd(log(bi_sev$claim_amount), na.rm = TRUE)

# -----------------------------
# 3. Simulate aggregate loss
# -----------------------------
set.seed(123)
n_sim <- 10000

agg_losses <- numeric(n_sim)
claim_counts <- numeric(n_sim)

for (i in 1:n_sim) {
  
  # simulate total number of claims for the whole portfolio
  N_i <- rpois(1, lambda = total_claims)
  claim_counts[i] <- N_i
  
  if (N_i > 0) {
    claims_i <- rlnorm(N_i, meanlog = meanlog_hat, sdlog = sdlog_hat)
    agg_losses[i] <- sum(claims_i)
  }
}

# -----------------------------
# 4. Summary statistics
# -----------------------------
summary_stats <- data.frame(
  Metric = c("Expected loss", "SD", "Average claim count", "P50", "P95", "P99"),
  Value = c(
    mean(agg_losses),
    sd(agg_losses),
    mean(claim_counts),
    quantile(agg_losses, 0.50),
    quantile(agg_losses, 0.95),
    quantile(agg_losses, 0.99)
  )
)

print(summary_stats)

# optional: easier formatting
summary_stats$Value <- format(round(summary_stats$Value, 2),
                              scientific = FALSE, big.mark = ",")
print(summary_stats)

# -----------------------------
# 5. Histogram
# -----------------------------
hist(agg_losses,
     breaks = 50,
     main = "Simulated Aggregate BI Gross Loss",
     xlab = "Aggregate Gross Loss")





library(dplyr)
library(MASS)
library(readxl)

# =========================================================
# BUSINESS INTERRUPTION ANALYSIS
# TIGHTER / MORE REALISTIC PRODUCT VERSION
# WITH INFLATION INSIDE PRICING
# =========================================================

# =========================================================
# 0. READ INFLATION DATA
# =========================================================
inflation_tbl <- read_excel("~/Downloads/SOA_2026_Case_Study_Materials 2/srcsc-2026-interest-and-inflation.xlsx", skip = 2) %>%
  janitor::clean_names() %>%
  rename(
    inflation = inflation,
    year = year
  ) %>%
  filter(!is.na(year), !is.na(inflation)) %>%
  arrange(year)

# latest 3-year moving average inflation
inflation_history <- tail(inflation_tbl$inflation, 3)
inflation_rate <- mean(inflation_history, na.rm = TRUE)

# 1-year pricing horizon
years_forward <- 1
inflation_factor <- (1 + inflation_rate)^years_forward

cat("\n--- INFLATION ASSUMPTION ---\n")
cat("Latest 3 inflation rates =", round(inflation_history, 4), "\n")
cat("Average inflation rate   =", round(inflation_rate, 4), "\n")
cat("Inflation factor used    =", round(inflation_factor, 4), "\n")

# =========================================================
# 1. PREP DATA
# =========================================================
freq <- bi_freq %>%
  mutate(
    solar_system = factor(solar_system),
    exposure = pmax(exposure, 1e-6)
  )

sev <- bi_sev %>%
  mutate(
    solar_system = factor(solar_system),
    claim_amount = claim_amount * inflation_factor
  ) %>%
  filter(!is.na(claim_amount), claim_amount > 0)

# =========================================================
# 2. DESCRIPTIVE SUMMARY
# =========================================================
freq_system <- freq %>%
  group_by(solar_system) %>%
  summarise(
    total_claims   = sum(claim_count, na.rm = TRUE),
    total_exposure = sum(exposure, na.rm = TRUE),
    claim_rate     = total_claims / total_exposure,
    .groups = "drop"
  )

sev_system <- sev %>%
  group_by(solar_system) %>%
  summarise(
    n_claims     = n(),
    mean_claim   = mean(claim_amount, na.rm = TRUE),
    median_claim = median(claim_amount, na.rm = TRUE),
    p95_claim    = quantile(claim_amount, 0.95, na.rm = TRUE),
    p99_claim    = quantile(claim_amount, 0.99, na.rm = TRUE),
    max_claim    = max(claim_amount, na.rm = TRUE),
    .groups = "drop"
  )

system_summary <- freq_system %>%
  left_join(sev_system, by = "solar_system") %>%
  mutate(expected_loss_per_exposure = claim_rate * mean_claim)

cat("\n--- SYSTEM SUMMARY ---\n")
print(system_summary)

# =========================================================
# 3. BASELINE FREQUENCY MODEL
# =========================================================
pois_mod <- glm(
  claim_count ~ solar_system,
  family = poisson(link = "log"),
  offset = log(exposure),
  data = freq
)

poisson_dispersion <- sum(residuals(pois_mod, type = "pearson")^2) / pois_mod$df.residual

if (poisson_dispersion > 1.2) {
  freq_model <- glm.nb(
    claim_count ~ solar_system + offset(log(exposure)),
    data = freq
  )
  freq_model_type <- "Negative Binomial"
} else {
  freq_model <- pois_mod
  freq_model_type <- "Poisson"
}

freq$pred_claims <- predict(freq_model, newdata = freq, type = "response")

lambda_system <- freq %>%
  group_by(solar_system) %>%
  summarise(
    expected_claims   = sum(pred_claims, na.rm = TRUE),
    total_exposure    = sum(exposure, na.rm = TRUE),
    fitted_claim_rate = expected_claims / total_exposure,
    .groups = "drop"
  )

# =========================================================
# 4. BASELINE SEVERITY MODEL
# =========================================================
sev_model <- glm(
  log(claim_amount) ~ solar_system,
  family = gaussian(),
  data = sev
)

sev_sigma <- sd(residuals(sev_model))

sev$pred_log_claim <- predict(sev_model, newdata = sev, type = "response")

sev_system_model <- sev %>%
  group_by(solar_system) %>%
  summarise(
    meanlog_hat = mean(pred_log_claim, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    fitted_mean_severity = exp(meanlog_hat + 0.5 * sev_sigma^2)
  )

# =========================================================
# 5. BASELINE PRICING INPUTS
# =========================================================
pricing_inputs_base <- lambda_system %>%
  left_join(sev_system_model, by = "solar_system") %>%
  mutate(
    meanlog = meanlog_hat,
    sdlog = sev_sigma,
    expected_loss = expected_claims * fitted_mean_severity
  ) %>%
  dplyr::select(
    solar_system,
    expected_claims,
    fitted_claim_rate,
    fitted_mean_severity,
    meanlog,
    sdlog,
    expected_loss
  )

cat("\n--- MODEL TYPE ---\n")
print(freq_model_type)

cat("\n--- BASELINE PRICING INPUTS ---\n")
print(pricing_inputs_base)

# =========================================================
# 6. OPTIMAL BALANCED PRODUCT DESIGN
# =========================================================

waiting_period_days <- 21
deductible          <- 150000
coinsurance         <- 0.80
policy_limit        <- 400000

expense_loading <- 0.10
risk_margin     <- 0.15
profit_margin   <- 0.05

# approximate daily BI loss from inflated observed severities
daily_loss_assumed <- median(sev$claim_amount, na.rm = TRUE) / 30
# =========================================================
# 7. APPLY PRODUCT TO OBSERVED SEVERITY DATA
# =========================================================
sev_design <- sev %>%
  mutate(
    equiv_days = pmax(1, claim_amount / daily_loss_assumed),
    covered_fraction = pmax(0, (equiv_days - waiting_period_days) / equiv_days),
    covered_loss = claim_amount * covered_fraction,
    loss_after_deductible = pmax(0, covered_loss - deductible),
    insurer_paid = pmin(policy_limit, coinsurance * loss_after_deductible)
  )

design_check <- sev_design %>%
  summarise(
    avg_gross_claim = mean(claim_amount, na.rm = TRUE),
    avg_paid_claim  = mean(insurer_paid, na.rm = TRUE),
    payable_prop    = mean(insurer_paid > 0, na.rm = TRUE)
  )

cat("\n--- DESIGN CHECK ---\n")
print(design_check)

post_design_system <- sev_design %>%
  group_by(solar_system) %>%
  summarise(
    payable_prop = mean(insurer_paid > 0, na.rm = TRUE),
    mean_severity_post = mean(insurer_paid[insurer_paid > 0], na.rm = TRUE),
    meanlog_post = mean(log(insurer_paid[insurer_paid > 0]), na.rm = TRUE),
    sdlog_post   = sd(log(insurer_paid[insurer_paid > 0]), na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    mean_severity_post = ifelse(is.nan(mean_severity_post), 0, mean_severity_post),
    meanlog_post = ifelse(is.na(meanlog_post), 0, meanlog_post),
    sdlog_post = ifelse(is.na(sdlog_post) | sdlog_post <= 0, 0.01, sdlog_post)
  )

pricing_inputs_post <- lambda_system %>%
  left_join(post_design_system, by = "solar_system") %>%
  mutate(
    expected_claims = expected_claims * payable_prop,
    meanlog = meanlog_post,
    sdlog   = sdlog_post,
    expected_loss = expected_claims * mean_severity_post
  ) %>%
  dplyr::select(
    solar_system,
    expected_claims,
    payable_prop,
    meanlog,
    sdlog,
    expected_loss
  )

cat("\n--- POST-DESIGN PRICING INPUTS ---\n")
print(pricing_inputs_post)

# =========================================================
# 8. SIMULATION FUNCTION
# =========================================================
simulate_portfolio <- function(pricing_tbl, n_sim = 10000, seed = 123) {
  set.seed(seed)
  
  sys_names <- gsub(" ", "_", as.character(pricing_tbl$solar_system))
  sim_mat <- matrix(0, nrow = n_sim, ncol = length(sys_names))
  colnames(sim_mat) <- sys_names
  
  for (i in 1:n_sim) {
    for (j in 1:nrow(pricing_tbl)) {
      n_claims <- rpois(1, pricing_tbl$expected_claims[j])
      
      if (n_claims > 0) {
        sim_mat[i, j] <- sum(
          rlnorm(
            n_claims,
            meanlog = pricing_tbl$meanlog[j],
            sdlog   = pricing_tbl$sdlog[j]
          )
        )
      }
    }
  }
  
  sim_df <- as.data.frame(sim_mat)
  sim_df$total_loss <- rowSums(sim_df)
  sim_df
}

summarise_portfolio <- function(sim_df, label) {
  data.frame(
    portfolio = label,
    expected_loss = mean(sim_df$total_loss),
    variance = var(sim_df$total_loss),
    sd = sd(sim_df$total_loss),
    p95 = as.numeric(quantile(sim_df$total_loss, 0.95)),
    p99 = as.numeric(quantile(sim_df$total_loss, 0.99))
  )
}

# =========================================================
# 9. RUN SIMULATIONS
# =========================================================
n_sim <- 10000

sim_base <- simulate_portfolio(pricing_inputs_base, n_sim = n_sim, seed = 123)
sim_post <- simulate_portfolio(pricing_inputs_post, n_sim = n_sim, seed = 123)

summary_base <- summarise_portfolio(sim_base, "Baseline (Before Product)")
summary_post <- summarise_portfolio(sim_post, "Post-Product")

cat("\n--- BASELINE SUMMARY ---\n")
print(summary_base)

cat("\n--- POST-PRODUCT SUMMARY ---\n")
print(summary_post)

# =========================================================
# 10. PRICING METRICS
# =========================================================
price_metrics <- function(loss_summary_df, charged_premium = NULL) {
  expected_loss <- loss_summary_df$expected_loss[1]
  p99           <- loss_summary_df$p99[1]
  capital_99    <- p99 - expected_loss
  
  required_premium <- expected_loss * (1 + expense_loading + risk_margin + profit_margin)
  
  if (is.null(charged_premium)) {
    charged_premium <- required_premium
  }
  
  expected_expense <- expense_loading * expected_loss
  expected_profit  <- charged_premium - expected_loss - expected_expense
  roc              <- ifelse(capital_99 > 0, expected_profit / capital_99, NA)
  
  data.frame(
    expected_loss = expected_loss,
    p99 = p99,
    required_premium = required_premium,
    charged_premium = charged_premium,
    capital_99 = capital_99,
    expected_profit = expected_profit,
    ROC = roc
  )
}

metrics_base <- price_metrics(summary_base)
metrics_post <- price_metrics(summary_post)

comparison_summary <- bind_rows(
  cbind(scenario = "Baseline", metrics_base),
  cbind(scenario = "Post-Product", metrics_post)
)

cat("\n--- PRICING COMPARISON ---\n")
print(comparison_summary)

# =========================================================
# 11. SOLAR SYSTEM COMPARISON
# =========================================================
system_compare <- pricing_inputs_base %>%
  dplyr::select(solar_system, expected_loss_base = expected_loss) %>%
  left_join(
    pricing_inputs_post %>%
      dplyr::select(solar_system, expected_loss_post = expected_loss),
    by = "solar_system"
  ) %>%
  mutate(
    premium_base = expected_loss_base * (1 + expense_loading + risk_margin + profit_margin),
    premium_post = expected_loss_post * (1 + expense_loading + risk_margin + profit_margin),
    premium_change = premium_post - premium_base,
    premium_change_pct = premium_change / premium_base
  )

cat("\n--- SOLAR SYSTEM COMPARISON ---\n")
print(system_compare)

# =========================================================
# 12. STRESS TESTING
# =========================================================
stress_portfolio <- function(pricing_tbl, freq_mult, sev_mult, n_sim = 10000, seed = 456) {
  set.seed(seed)
  
  totals <- replicate(n_sim, {
    total <- 0
    for (j in 1:nrow(pricing_tbl)) {
      n_claims <- rpois(1, freq_mult * pricing_tbl$expected_claims[j])
      if (n_claims > 0) {
        total <- total + sum(
          sev_mult * rlnorm(
            n_claims,
            meanlog = pricing_tbl$meanlog[j],
            sdlog   = pricing_tbl$sdlog[j]
          )
        )
      }
    }
    total
  })
  
  data.frame(
    expected_loss = mean(totals),
    p95 = as.numeric(quantile(totals, 0.95)),
    p99 = as.numeric(quantile(totals, 0.99))
  )
}

stress_base <- stress_portfolio(pricing_inputs_base, freq_mult = 1.5, sev_mult = 1.75)
stress_post <- stress_portfolio(pricing_inputs_post, freq_mult = 1.5, sev_mult = 1.75)

cat("\n--- STRESS TEST: BASELINE ---\n")
print(stress_base)

cat("\n--- STRESS TEST: POST-PRODUCT ---\n")
print(stress_post)

# =========================================================
# 13. DEPENDENCY / COMMON SHOCK
# =========================================================
dependency_portfolio <- function(pricing_tbl,
                                 common_prob = 0.05,
                                 freq_uplift = 1.30,
                                 sev_uplift  = 1.40,
                                 n_sim = 10000,
                                 seed = 789) {
  set.seed(seed)
  
  totals <- replicate(n_sim, {
    common_shock <- rbinom(1, 1, common_prob)
    total <- 0
    
    for (j in 1:nrow(pricing_tbl)) {
      lambda_use <- pricing_tbl$expected_claims[j]
      sev_mult   <- 1
      
      if (common_shock == 1) {
        lambda_use <- lambda_use * freq_uplift
        sev_mult   <- sev_uplift
      }
      
      n_claims <- rpois(1, lambda_use)
      
      if (n_claims > 0) {
        total <- total + sum(
          sev_mult * rlnorm(
            n_claims,
            meanlog = pricing_tbl$meanlog[j],
            sdlog   = pricing_tbl$sdlog[j]
          )
        )
      }
    }
    
    total
  })
  
  data.frame(
    expected_loss = mean(totals),
    p95 = as.numeric(quantile(totals, 0.95)),
    p99 = as.numeric(quantile(totals, 0.99))
  )
}

dependency_base <- dependency_portfolio(pricing_inputs_base)
dependency_post <- dependency_portfolio(pricing_inputs_post)

cat("\n--- DEPENDENCY TEST: BASELINE ---\n")
print(dependency_base)

cat("\n--- DEPENDENCY TEST: POST-PRODUCT ---\n")
print(dependency_post)





library(ggplot2)




# -----------------------------
# Baseline aggregate loss distribution
# -----------------------------
ggplot(sim_base, aes(x = total_loss)) +
  geom_histogram(bins = 50, fill = "grey", color = "black") +
  labs(
    title = "Baseline Aggregate Loss Distribution",
    x = "Aggregate Loss",
    y = "Frequency"
  ) +
  theme_minimal()

# -----------------------------
# Post-product aggregate loss distribution
# -----------------------------
ggplot(sim_post, aes(x = total_loss)) +
  geom_histogram(bins = 50, fill = "grey", color = "black") +
  labs(
    title = "Post-Product Aggregate Loss Distribution",
    x = "Aggregate Loss",
    y = "Frequency"
  ) +
  theme_minimal()

library(dplyr)
library(ggplot2)

# Combine both simulation outputs
plot_df <- bind_rows(
  sim_base %>% mutate(Scenario = "Baseline"),
  sim_post %>% mutate(Scenario = "Post-Product")
)

# Overlay both distributions on one graph
ggplot(plot_df, aes(x = total_loss, fill = Scenario)) +
  geom_histogram(position = "identity", alpha = 0.5, bins = 50, color = "black") +
  labs(
    title = "Aggregate Loss Distribution: Baseline vs Post-Product",
    x = "Aggregate Loss",
    y = "Frequency"
  ) +
  theme_minimal()




# =========================================================
# 14. RANGE-BASED PRODUCT DESIGN TESTING
# BUSINESS INTERRUPTION VERSION
# =========================================================

library(dplyr)
library(ggplot2)

# 14.1 Define plausible BI product parameter ranges
design_grid <- expand.grid(
  deductible = c(150000, 250000, 350000),
  waiting_period = c(14, 21, 30),
  policy_limit = c(400000, 500000, 750000),
  coinsurance = c(0.70, 0.80, 0.90),
  stringsAsFactors = FALSE
)

# 14.2 Function to test one BI product design
run_bi_design_option <- function(
    sev_data,
    lambda_tbl,
    deductible,
    waiting_period,
    policy_limit,
    coinsurance,
    n_sim = 3000,
    seed = 123
) {
  
  # approximate daily BI loss from inflated claim amounts
  daily_loss_assumed <- median(sev_data$claim_amount, na.rm = TRUE) / 30
  
  sev_temp <- sev_data %>%
    mutate(
      equiv_days = pmax(1, claim_amount / daily_loss_assumed),
      covered_fraction = pmax(0, (equiv_days - waiting_period) / equiv_days),
      covered_loss = claim_amount * covered_fraction,
      loss_after_deductible = pmax(covered_loss - deductible, 0),
      insurer_paid = pmin(policy_limit, coinsurance * loss_after_deductible)
    )
  
  post_design_system <- sev_temp %>%
    group_by(solar_system) %>%
    summarise(
      payable_prop = mean(insurer_paid > 0, na.rm = TRUE),
      mean_severity_post = mean(insurer_paid[insurer_paid > 0], na.rm = TRUE),
      meanlog_post = mean(log(insurer_paid[insurer_paid > 0]), na.rm = TRUE),
      sdlog_post = sd(log(insurer_paid[insurer_paid > 0]), na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      mean_severity_post = ifelse(is.nan(mean_severity_post), 0, mean_severity_post),
      meanlog_post = ifelse(is.nan(meanlog_post) | is.infinite(meanlog_post), 0, meanlog_post),
      sdlog_post = ifelse(is.na(sdlog_post) | sdlog_post <= 0, 0.01, sdlog_post)
    )
  
  pricing_inputs_temp <- lambda_tbl %>%
    left_join(post_design_system, by = "solar_system") %>%
    mutate(
      payable_prop = ifelse(is.na(payable_prop), 0, payable_prop),
      mean_severity_post = ifelse(is.na(mean_severity_post), 0, mean_severity_post),
      meanlog_post = ifelse(is.na(meanlog_post), 0, meanlog_post),
      sdlog_post = ifelse(is.na(sdlog_post), 0.01, sdlog_post),
      expected_claims = expected_claims * payable_prop,
      meanlog = meanlog_post,
      sdlog = sdlog_post,
      expected_loss = expected_claims * mean_severity_post
    ) %>%
    dplyr::select(solar_system, expected_claims, payable_prop, meanlog, sdlog, expected_loss)
  
  sim_temp <- simulate_portfolio(pricing_inputs_temp, n_sim = n_sim, seed = seed)
  summary_temp <- summarise_portfolio(sim_temp, "design_option")
  metrics_temp <- price_metrics(summary_temp)
  
  data.frame(
    deductible = deductible,
    waiting_period = waiting_period,
    policy_limit = policy_limit,
    coinsurance = coinsurance,
    expected_loss = summary_temp$expected_loss,
    p95 = summary_temp$p95,
    p99 = summary_temp$p99,
    required_premium = metrics_temp$required_premium,
    charged_premium = metrics_temp$charged_premium,
    capital_99 = metrics_temp$capital_99,
    expected_profit = metrics_temp$expected_profit,
    ROC = metrics_temp$ROC
  )
}

# 14.3 Run all combinations
grid_results <- lapply(
  seq_len(nrow(design_grid)),
  function(i) {
    run_bi_design_option(
      sev_data = sev,
      lambda_tbl = lambda_system,
      deductible = design_grid$deductible[i],
      waiting_period = design_grid$waiting_period[i],
      policy_limit = design_grid$policy_limit[i],
      coinsurance = design_grid$coinsurance[i],
      n_sim = 3000,
      seed = 100 + i
    )
  }
)

grid_results <- bind_rows(grid_results)

cat("\n--- RANGE-BASED BI PRODUCT DESIGN RESULTS ---\n")
print(grid_results)

# 14.4 Rank designs by ROC
grid_ranked <- grid_results %>%
  arrange(desc(ROC), expected_loss)

cat("\n--- TOP BI DESIGNS BY ROC ---\n")
print(head(grid_ranked, 10))

# 14.5 Balanced shortlist
balanced_designs <- grid_results %>%
  filter(
    deductible >= 150000,
    deductible <= 350000,
    waiting_period >= 14,
    waiting_period <= 30,
    capital_99 < quantile(capital_99, 0.75, na.rm = TRUE)
  ) %>%
  arrange(desc(ROC), expected_loss)

cat("\n--- BALANCED BI DESIGN SHORTLIST ---\n")
print(head(balanced_designs, 10))

# 14.6 Highest profit options
grid_profit_rank <- grid_results %>%
  arrange(desc(expected_profit))

cat("\n--- TOP BI DESIGNS BY PROFIT ---\n")
print(head(grid_profit_rank, 10))

# 14.7 Optional plots
ggplot(grid_results, aes(x = ROC, y = expected_loss)) +
  geom_point() +
  labs(
    title = "BI Design Trade-off: Expected Loss vs ROC",
    x = "Return on Capital (ROC)",
    y = "Expected Loss"
  )

ggplot(grid_results, aes(x = factor(deductible), y = expected_loss)) +
  geom_boxplot() +
  labs(
    title = "Expected Loss by Deductible",
    x = "Deductible",
    y = "Expected Loss"
  )

ggplot(grid_results, aes(x = factor(waiting_period), y = expected_loss)) +
  geom_boxplot() +
  labs(
    title = "Expected Loss by Waiting Period",
    x = "Waiting Period (days)",
    y = "Expected Loss"
  )

ggplot(grid_results, aes(x = factor(policy_limit), y = expected_loss)) +
  geom_boxplot() +
  labs(
    title = "Expected Loss by Policy Limit",
    x = "Policy Limit",
    y = "Expected Loss"
  )

ggplot(grid_results, aes(x = factor(coinsurance), y = expected_loss)) +
  geom_boxplot() +
  labs(
    title = "Expected Loss by Coinsurance",
    x = "Coinsurance",
    y = "Expected Loss"
  )




# =========================================================
# 3(b) STRESS TESTING — BEFORE vs AFTER PRODUCT
# BUSINESS INTERRUPTION
# =========================================================

library(dplyr)

# -----------------------------
# Base frequency + severity
# -----------------------------
lambda_hat <- sum(bi_freq$claim_count, na.rm = TRUE) / 
  sum(bi_freq$exposure, na.rm = TRUE)

portfolio_exposure <- sum(bi_freq$exposure, na.rm = TRUE)
expected_N <- lambda_hat * portfolio_exposure

meanlog_hat <- mean(log(bi_sev$claim_amount), na.rm = TRUE)
sdlog_hat   <- sd(log(bi_sev$claim_amount), na.rm = TRUE)

# -----------------------------
# Your chosen product design
# -----------------------------
waiting_period_days <- 21
deductible          <- 150000
coinsurance         <- 0.80
policy_limit        <- 400000

daily_loss_assumed <- median(bi_sev$claim_amount, na.rm = TRUE) / 30

# -----------------------------
# Simulation function
# -----------------------------
simulate_aggregate_bi <- function(expected_N, meanlog_hat, sdlog_hat,
                                  freq_multiplier = 1,
                                  sev_multiplier = 1,
                                  apply_product = FALSE,
                                  waiting_period_days = 0,
                                  deductible = 0,
                                  coinsurance = 1,
                                  policy_limit = Inf,
                                  daily_loss_assumed,
                                  n_sim = 10000) {
  
  agg <- numeric(n_sim)
  
  for (i in 1:n_sim) {
    
    N_i <- rpois(1, lambda = expected_N * freq_multiplier)
    
    if (N_i > 0) {
      claims_i <- rlnorm(
        N_i,
        meanlog = meanlog_hat + log(sev_multiplier),
        sdlog = sdlog_hat
      )
      
      if (apply_product) {
        equiv_days <- pmax(1, claims_i / daily_loss_assumed)
        covered_fraction <- pmax(0, (equiv_days - waiting_period_days) / equiv_days)
        covered_loss <- claims_i * covered_fraction
        loss_after_deductible <- pmax(covered_loss - deductible, 0)
        net_claims <- pmin(policy_limit, coinsurance * loss_after_deductible)
      } else {
        net_claims <- claims_i
      }
      
      agg[i] <- sum(net_claims)
    } else {
      agg[i] <- 0
    }
  }
  
  agg
}

# -----------------------------
# BEFORE product
# -----------------------------
set.seed(123)

base_before <- simulate_aggregate_bi(
  expected_N, meanlog_hat, sdlog_hat,
  freq_multiplier = 1,
  sev_multiplier = 1,
  apply_product = FALSE,
  daily_loss_assumed = daily_loss_assumed
)

moderate_before <- simulate_aggregate_bi(
  expected_N, meanlog_hat, sdlog_hat,
  freq_multiplier = 1.20,
  sev_multiplier = 1.25,
  apply_product = FALSE,
  daily_loss_assumed = daily_loss_assumed
)

extreme_before <- simulate_aggregate_bi(
  expected_N, meanlog_hat, sdlog_hat,
  freq_multiplier = 1.50,
  sev_multiplier = 1.75,
  apply_product = FALSE,
  daily_loss_assumed = daily_loss_assumed
)

# -----------------------------
# AFTER product
# -----------------------------
base_after <- simulate_aggregate_bi(
  expected_N, meanlog_hat, sdlog_hat,
  freq_multiplier = 1,
  sev_multiplier = 1,
  apply_product = TRUE,
  waiting_period_days = waiting_period_days,
  deductible = deductible,
  coinsurance = coinsurance,
  policy_limit = policy_limit,
  daily_loss_assumed = daily_loss_assumed
)

moderate_after <- simulate_aggregate_bi(
  expected_N, meanlog_hat, sdlog_hat,
  freq_multiplier = 1.20,
  sev_multiplier = 1.25,
  apply_product = TRUE,
  waiting_period_days = waiting_period_days,
  deductible = deductible,
  coinsurance = coinsurance,
  policy_limit = policy_limit,
  daily_loss_assumed = daily_loss_assumed
)

extreme_after <- simulate_aggregate_bi(
  expected_N, meanlog_hat, sdlog_hat,
  freq_multiplier = 1.50,
  sev_multiplier = 1.75,
  apply_product = TRUE,
  waiting_period_days = waiting_period_days,
  deductible = deductible,
  coinsurance = coinsurance,
  policy_limit = policy_limit,
  daily_loss_assumed = daily_loss_assumed
)

# -----------------------------
# Comparison table
# -----------------------------
comparison_stress <- rbind(
  data.frame(
    basis = "Before Product",
    scenario = "Base",
    mean = round(mean(base_before), 0),
    p95 = round(as.numeric(quantile(base_before, 0.95)), 0),
    p99 = round(as.numeric(quantile(base_before, 0.99)), 0)
  ),
  data.frame(
    basis = "Before Product",
    scenario = "Moderate Stress",
    mean = round(mean(moderate_before), 0),
    p95 = round(as.numeric(quantile(moderate_before, 0.95)), 0),
    p99 = round(as.numeric(quantile(moderate_before, 0.99)), 0)
  ),
  data.frame(
    basis = "Before Product",
    scenario = "Extreme Stress",
    mean = round(mean(extreme_before), 0),
    p95 = round(as.numeric(quantile(extreme_before, 0.95)), 0),
    p99 = round(as.numeric(quantile(extreme_before, 0.99)), 0)
  ),
  data.frame(
    basis = "After Product",
    scenario = "Base",
    mean = round(mean(base_after), 0),
    p95 = round(as.numeric(quantile(base_after, 0.95)), 0),
    p99 = round(as.numeric(quantile(base_after, 0.99)), 0)
  ),
  data.frame(
    basis = "After Product",
    scenario = "Moderate Stress",
    mean = round(mean(moderate_after), 0),
    p95 = round(as.numeric(quantile(moderate_after, 0.95)), 0),
    p99 = round(as.numeric(quantile(moderate_after, 0.99)), 0)
  ),
  data.frame(
    basis = "After Product",
    scenario = "Extreme Stress",
    mean = round(mean(extreme_after), 0),
    p95 = round(as.numeric(quantile(extreme_after, 0.95)), 0),
    p99 = round(as.numeric(quantile(extreme_after, 0.99)), 0)
  )
)

comparison_stress

# -----------------------------
# Reduction table
# -----------------------------
before_tbl <- comparison_stress[comparison_stress$basis == "Before Product", ]
after_tbl  <- comparison_stress[comparison_stress$basis == "After Product", ]

before_tbl <- before_tbl[match(c("Base", "Moderate Stress", "Extreme Stress"), before_tbl$scenario), ]
after_tbl  <- after_tbl[match(c("Base", "Moderate Stress", "Extreme Stress"), after_tbl$scenario), ]

reduction_table <- data.frame(
  scenario = before_tbl$scenario,
  mean_before = before_tbl$mean,
  mean_after = after_tbl$mean,
  mean_reduction_pct = round(100 * (before_tbl$mean - after_tbl$mean) / before_tbl$mean, 2),
  p95_before = before_tbl$p95,
  p95_after = after_tbl$p95,
  p95_reduction_pct = round(100 * (before_tbl$p95 - after_tbl$p95) / before_tbl$p95, 2),
  p99_before = before_tbl$p99,
  p99_after = after_tbl$p99,
  p99_reduction_pct = round(100 * (before_tbl$p99 - after_tbl$p99) / before_tbl$p99, 2)
)

reduction_table





# =========================================================
# QUESTION 4 — POST-PRODUCT ANALYSIS (BUSINESS INTERRUPTION)
# =========================================================

library(dplyr)
library(ggplot2)
library(MASS)

# ---------------------------------------------------------
# 0. CHECK DATA
# ---------------------------------------------------------
colnames(bi_freq)
colnames(bi_sev)

# ---------------------------------------------------------
# 1. POST-PRODUCT SEVERITY
# ---------------------------------------------------------
# Assumes these product terms already exist:
# waiting_period_days
# deductible
# coinsurance
# policy_limit

daily_loss_assumed <- median(bi_sev$claim_amount, na.rm = TRUE) / 30

apply_bi_product <- function(gross_loss,
                             waiting_period_days,
                             deductible,
                             coinsurance,
                             policy_limit,
                             daily_loss_assumed) {
  
  waiting_deduction <- waiting_period_days * daily_loss_assumed
  
  net_loss <- pmax(gross_loss - waiting_deduction - deductible, 0)
  net_loss <- net_loss * coinsurance
  net_loss <- pmin(net_loss, policy_limit)
  
  return(net_loss)
}

bi_sev_post <- bi_sev %>%
  mutate(
    net_claim_amount = apply_bi_product(
      gross_loss = claim_amount,
      waiting_period_days = waiting_period_days,
      deductible = deductible,
      coinsurance = coinsurance,
      policy_limit = policy_limit,
      daily_loss_assumed = daily_loss_assumed
    )
  )

summary(bi_sev_post$net_claim_amount)

# ---------------------------------------------------------
# 4.1 RISK IDENTIFICATION
# WHICH VARIABLES MATTER + WHICH SOLAR SYSTEM IS RISKIER
# ---------------------------------------------------------

# -----------------------------
# 4.1A Frequency model
# -----------------------------
freq_model_bi <- glm(
  claim_count ~ solar_system +
    production_load +
    factor(energy_backup_score) +
    supply_chain_index +
    avg_crew_exp +
    maintenance_freq,
  family = poisson(link = "log"),
  offset = log(exposure),
  data = bi_freq
)

summary(freq_model_bi)

# incidence rate ratios
freq_irrs <- exp(coef(freq_model_bi))
freq_irrs_table <- data.frame(
  Variable = names(freq_irrs),
  IRR = round(freq_irrs, 3),
  row.names = NULL
)

freq_irrs_table

# optional: tidy coefficient table with p-values
freq_coef_table <- data.frame(
  Variable = rownames(summary(freq_model_bi)$coefficients),
  Estimate = summary(freq_model_bi)$coefficients[, 1],
  Std_Error = summary(freq_model_bi)$coefficients[, 2],
  z_value = summary(freq_model_bi)$coefficients[, 3],
  p_value = summary(freq_model_bi)$coefficients[, 4],
  IRR = exp(summary(freq_model_bi)$coefficients[, 1]),
  row.names = NULL
)

freq_coef_table

# -----------------------------
# 4.1B Solar system summaries
# -----------------------------
system_freq_summary <- bi_freq %>%
  group_by(solar_system) %>%
  summarise(
    total_claims = sum(claim_count, na.rm = TRUE),
    total_exposure = sum(exposure, na.rm = TRUE),
    claim_rate = total_claims / total_exposure,
    avg_production_load = mean(production_load, na.rm = TRUE),
    avg_supply_chain_index = mean(supply_chain_index, na.rm = TRUE),
    avg_energy_backup_score = mean(energy_backup_score, na.rm = TRUE),
    avg_crew_exp = mean(avg_crew_exp, na.rm = TRUE),
    avg_maintenance_freq = mean(maintenance_freq, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(claim_rate))

system_freq_summary

system_sev_summary_gross <- bi_sev %>%
  group_by(solar_system) %>%
  summarise(
    avg_gross_claim = mean(claim_amount, na.rm = TRUE),
    max_gross_claim = max(claim_amount, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(avg_gross_claim))

system_sev_summary_gross

system_sev_summary_net <- bi_sev_post %>%
  group_by(solar_system) %>%
  summarise(
    avg_net_claim = mean(net_claim_amount, na.rm = TRUE),
    max_net_claim = max(net_claim_amount, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(avg_net_claim))

system_sev_summary_net

system_risk_summary <- system_freq_summary %>%
  left_join(system_sev_summary_gross, by = "solar_system") %>%
  left_join(system_sev_summary_net, by = "solar_system") %>%
  mutate(
    gross_risk_score = claim_rate * avg_gross_claim,
    net_risk_score = claim_rate * avg_net_claim
  ) %>%
  arrange(desc(net_risk_score))

system_risk_summary

# identify riskiest solar system
riskiest_system <- as.character(system_risk_summary$solar_system[1])
riskiest_system

# -----------------------------
# 4.1C Text results for report
# -----------------------------
system_text_results <- system_risk_summary %>%
  mutate(
    interpretation = case_when(
      solar_system == riskiest_system ~
        paste0(
          "Highest BI risk overall. Claim rate = ",
          round(claim_rate, 3),
          ", average gross claim = ",
          round(avg_gross_claim, 0),
          ", average net claim = ",
          round(avg_net_claim, 0),
          ". This system has the highest combined post-product risk score."
        ),
      solar_system != riskiest_system & claim_rate >= median(claim_rate) ~
        paste0(
          "Moderately elevated BI risk. Claim rate = ",
          round(claim_rate, 3),
          ", average gross claim = ",
          round(avg_gross_claim, 0),
          ", average net claim = ",
          round(avg_net_claim, 0),
          ". This system remains a material contributor to interruption losses."
        ),
      TRUE ~
        paste0(
          "Relatively lower BI risk. Claim rate = ",
          round(claim_rate, 3),
          ", average gross claim = ",
          round(avg_gross_claim, 0),
          ", average net claim = ",
          round(avg_net_claim, 0),
          ". This system shows the most stable interruption experience of the three."
        )
    )
  )

system_text_results

# print only the info you need to copy
system_text_results %>%
  dplyr::select(solar_system, interpretation)

# -----------------------------
# 4.1D Plots
# -----------------------------
ggplot(system_risk_summary, aes(x = reorder(solar_system, claim_rate), y = claim_rate)) +
  geom_col() +
  coord_flip() +
  labs(
    title = "BI Claim Rate by Solar System",
    x = "Solar System",
    y = "Claim Rate"
  )

ggplot(system_risk_summary, aes(x = reorder(solar_system, avg_net_claim), y = avg_net_claim)) +
  geom_col() +
  coord_flip() +
  labs(
    title = "Average Post-Product BI Claim by Solar System",
    x = "Solar System",
    y = "Average Net Claim"
  )

ggplot(system_risk_summary, aes(x = reorder(solar_system, net_risk_score), y = net_risk_score)) +
  geom_col() +
  coord_flip() +
  labs(
    title = "Post-Product BI Risk Score by Solar System",
    x = "Solar System",
    y = "Net Risk Score"
  )

# ---------------------------------------------------------
# 4.2 POST-PRODUCT AGGREGATE LOSS MODELLING
# ---------------------------------------------------------

# severity fit on positive post-product claims only
positive_net_claims <- bi_sev_post$net_claim_amount[bi_sev_post$net_claim_amount > 0]

meanlog_net <- mean(log(positive_net_claims), na.rm = TRUE)
sdlog_net   <- sd(log(positive_net_claims), na.rm = TRUE)

meanlog_net
sdlog_net

# system frequency assumptions
system_lambda <- bi_freq %>%
  group_by(solar_system) %>%
  summarise(
    exposure = sum(exposure, na.rm = TRUE),
    claim_rate = sum(claim_count, na.rm = TRUE) / sum(exposure, na.rm = TRUE),
    expected_N = exposure * claim_rate,
    .groups = "drop"
  )

system_lambda

simulate_bi_scenario <- function(system_lambda,
                                 meanlog_net,
                                 sdlog_net,
                                 freq_mult = NULL,
                                 sev_mult = NULL,
                                 n_sim = 10000) {
  
  if (is.null(freq_mult)) freq_mult <- rep(1, nrow(system_lambda))
  if (is.null(sev_mult))  sev_mult  <- rep(1, nrow(system_lambda))
  
  agg <- numeric(n_sim)
  
  for (i in seq_len(n_sim)) {
    total_loss <- 0
    
    for (j in seq_len(nrow(system_lambda))) {
      lambda_j <- system_lambda$expected_N[j] * freq_mult[j]
      N_j <- rpois(1, lambda = lambda_j)
      
      if (N_j > 0) {
        claims_j <- rlnorm(
          N_j,
          meanlog = meanlog_net + log(sev_mult[j]),
          sdlog = sdlog_net
        )
        total_loss <- total_loss + sum(claims_j)
      }
    }
    
    agg[i] <- total_loss
  }
  
  agg
}

summary_stats <- function(x) {
  data.frame(
    Mean = mean(x, na.rm = TRUE),
    SD   = sd(x, na.rm = TRUE),
    P95  = quantile(x, 0.95, na.rm = TRUE),
    P99  = quantile(x, 0.99, na.rm = TRUE),
    Max  = max(x, na.rm = TRUE)
  )
}

set.seed(123)

agg_bi_base <- simulate_bi_scenario(
  system_lambda = system_lambda,
  meanlog_net = meanlog_net,
  sdlog_net = sdlog_net,
  n_sim = 10000
)

summary_stats(agg_bi_base)

ggplot(data.frame(loss = agg_bi_base), aes(x = loss)) +
  geom_histogram(bins = 50) +
  labs(
    title = "Post-Product BI Aggregate Loss Distribution: Baseline",
    x = "Aggregate Net Loss",
    y = "Count"
  )

# ---------------------------------------------------------
# 4.3 SCENARIO TESTING
# best = frequency times 0.something
# moderate = worsen one solar system only
# worst = worsen all solar systems
# ---------------------------------------------------------

# best case
best_freq <- rep(0.75, nrow(system_lambda))
best_sev  <- rep(1.00, nrow(system_lambda))

# moderate case
moderate_freq <- rep(1.00, nrow(system_lambda))
moderate_sev  <- rep(1.00, nrow(system_lambda))
moderate_freq[system_lambda$solar_system == riskiest_system] <- 1.15
moderate_sev[system_lambda$solar_system == riskiest_system]  <- 1.20

# worst case
worst_freq <- rep(2.00, nrow(system_lambda))
worst_sev  <- rep(1.50, nrow(system_lambda))

set.seed(123)

agg_bi_best <- simulate_bi_scenario(
  system_lambda = system_lambda,
  meanlog_net = meanlog_net,
  sdlog_net = sdlog_net,
  freq_mult = best_freq,
  sev_mult = best_sev,
  n_sim = 10000
)

agg_bi_moderate <- simulate_bi_scenario(
  system_lambda = system_lambda,
  meanlog_net = meanlog_net,
  sdlog_net = sdlog_net,
  freq_mult = moderate_freq,
  sev_mult = moderate_sev,
  n_sim = 10000
)

agg_bi_worst <- simulate_bi_scenario(
  system_lambda = system_lambda,
  meanlog_net = meanlog_net,
  sdlog_net = sdlog_net,
  freq_mult = worst_freq,
  sev_mult = worst_sev,
  n_sim = 10000
)

scenario_results <- data.frame(
  Scenario = c(
    "Best case: smooth operations, attritional only",
    paste0("Moderate case: isolated system event (", riskiest_system, " only)"),
    "Worst case: catastrophic correlated multi-system failure"
  ),
  Frequency_Impact = c(
    "lambda x 0.75",
    paste0("lambda x 1.15 (", riskiest_system, " only)"),
    "lambda x 2.0 (all systems)"
  ),
  Severity_Impact = c(
    "mu unchanged",
    paste0("+20% severity (", riskiest_system, " only)"),
    "+50% severity"
  ),
  Expected_Loss = c(
    mean(agg_bi_best),
    mean(agg_bi_moderate),
    mean(agg_bi_worst)
  ),
  Expected_Loss_Million = round(c(
    mean(agg_bi_best),
    mean(agg_bi_moderate),
    mean(agg_bi_worst)
  ) / 1e6, 2)
)

scenario_results

# additional summary table
scenario_stats <- bind_rows(
  cbind(Scenario = "Baseline", summary_stats(agg_bi_base)),
  cbind(Scenario = "Best Case", summary_stats(agg_bi_best)),
  cbind(Scenario = "Moderate Case", summary_stats(agg_bi_moderate)),
  cbind(Scenario = "Worst Case", summary_stats(agg_bi_worst))
)

scenario_stats

# histograms
ggplot(data.frame(loss = agg_bi_best), aes(x = loss)) +
  geom_histogram(bins = 50) +
  labs(
    title = "Best Case BI Aggregate Loss Distribution",
    x = "Aggregate Net Loss",
    y = "Count"
  )

ggplot(data.frame(loss = agg_bi_moderate), aes(x = loss)) +
  geom_histogram(bins = 50) +
  labs(
    title = paste("Moderate Case BI Aggregate Loss Distribution (", riskiest_system, " worsened)", sep = ""),
    x = "Aggregate Net Loss",
    y = "Count"
  )

ggplot(data.frame(loss = agg_bi_worst), aes(x = loss)) +
  geom_histogram(bins = 50) +
  labs(
    title = "Worst Case BI Aggregate Loss Distribution",
    x = "Aggregate Net Loss",
    y = "Count"
  )

# ---------------------------------------------------------
# 4.4 RISK MATRIX / THREAT TABLE CONTENT
# ---------------------------------------------------------

bi_risk_matrix <- data.frame(
  Rank = 1:5,
  Threat = c(
    "Supply chain interruption",
    paste0("Concentrated risk in ", riskiest_system),
    "Insufficient energy backup capacity",
    "Operational disruption from high production strain",
    "Correlated multi-system interruption event"
  ),
  Impact = c(
    "Increases BI claim frequency by disrupting critical inputs and extending downtime.",
    paste0("Creates concentration risk because ", riskiest_system, " contributes the highest post-product BI risk score."),
    "Reduces system resilience and can lengthen downtime after operational disruption.",
    "Sustained operating strain can increase interruption frequency and worsen recovery time.",
    "Produces severe aggregate losses across all solar systems simultaneously and materially increases tail risk."
  ),
  Mitigation = c(
    "Diversify suppliers, strengthen contingency sourcing, and maintain critical inventory buffers.",
    paste0("Apply tighter underwriting, monitoring, and exposure limits in ", riskiest_system, "."),
    "Increase redundancy standards and improve minimum backup capacity requirements.",
    "Monitor utilisation thresholds, schedule preventive maintenance, and strengthen operational controls.",
    "Use scenario testing, policy limits, capital buffers, and reinsurance to manage portfolio tail exposure."
  ),
  row.names = NULL
)

bi_risk_matrix

# ---------------------------------------------------------
# 4.5 FINAL SUMMARY OUTPUTS
# ---------------------------------------------------------

final_q4_results <- bind_rows(
  cbind(Test = "Baseline", summary_stats(agg_bi_base)),
  cbind(Test = "Best Case", summary_stats(agg_bi_best)),
  cbind(Test = "Moderate Case", summary_stats(agg_bi_moderate)),
  cbind(Test = "Worst Case", summary_stats(agg_bi_worst))
)

final_q4_results

cat("\n==================== 4.1 KEY FINDINGS ====================\n")
cat("Riskiest solar system:", riskiest_system, "\n\n")
print(system_text_results %>% dplyr::select(solar_system, interpretation))

cat("\n==================== VARIABLE EFFECTS ====================\n")
print(freq_irrs_table)

cat("\n==================== 4.3 SCENARIO TABLE ====================\n")
print(scenario_results)

cat("\n==================== 4.4 RISK MATRIX ====================\n")
print(bi_risk_matrix)

cat("\n==================== 4.5 FINAL SUMMARY ====================\n")
print(final_q4_results)



# =========================================================
# 4.2 CORRELATED RISK SCENARIOS
# Business Interruption
# =========================================================

# system_lambda already created in your code:
# solar_system, exposure, claim_rate, expected_N

simulate_bi_correlated <- function(system_lambda,
                                   meanlog_net,
                                   sdlog_net,
                                   common_shock_prob = 0.05,
                                   freq_uplift_common = 1.50,
                                   sev_uplift_common  = 1.40,
                                   n_sim = 10000,
                                   seed = 123) {
  
  set.seed(seed)
  agg <- numeric(n_sim)
  shock_flag <- numeric(n_sim)
  
  for (i in seq_len(n_sim)) {
    
    total_loss <- 0
    
    # 1 = correlated multi-system shock occurs
    common_shock <- rbinom(1, 1, common_shock_prob)
    shock_flag[i] <- common_shock
    
    for (j in seq_len(nrow(system_lambda))) {
      
      lambda_j <- system_lambda$expected_N[j]
      sev_mult_j <- 1
      
      if (common_shock == 1) {
        lambda_j   <- lambda_j * freq_uplift_common
        sev_mult_j <- sev_uplift_common
      }
      
      N_j <- rpois(1, lambda = lambda_j)
      
      if (N_j > 0) {
        claims_j <- rlnorm(
          N_j,
          meanlog = meanlog_net + log(sev_mult_j),
          sdlog   = sdlog_net
        )
        total_loss <- total_loss + sum(claims_j)
      }
    }
    
    agg[i] <- total_loss
  }
  
  list(
    aggregate_loss = agg,
    shock_indicator = shock_flag
  )
}

summary_stats <- function(x) {
  data.frame(
    Mean = mean(x),
    SD   = sd(x),
    P50  = quantile(x, 0.50),
    P95  = quantile(x, 0.95),
    P99  = quantile(x, 0.99),
    Max  = max(x)
  )
}

# -----------------------------
# Baseline (independent-style)
# -----------------------------
agg_bi_base <- simulate_bi_scenario(
  system_lambda = system_lambda,
  meanlog_net = meanlog_net,
  sdlog_net = sdlog_net,
  n_sim = 10000
)

base_stats <- summary_stats(agg_bi_base)

# -----------------------------
# Correlated scenario
# -----------------------------
corr_out <- simulate_bi_correlated(
  system_lambda = system_lambda,
  meanlog_net = meanlog_net,
  sdlog_net = sdlog_net,
  common_shock_prob = 0.05,   # 5% chance of multi-system event
  freq_uplift_common = 1.50,  # 50% higher frequency during shock
  sev_uplift_common  = 1.40,  # 40% higher severity during shock
  n_sim = 10000,
  seed = 123
)

agg_bi_corr <- corr_out$aggregate_loss
corr_stats <- summary_stats(agg_bi_corr)

# -----------------------------
# Comparison table
# -----------------------------
correlation_comparison <- rbind(
  data.frame(
    Scenario = "Baseline / no common shock",
    base_stats
  ),
  data.frame(
    Scenario = "Correlated multi-system shock",
    corr_stats
  )
)

print(correlation_comparison)

# proportion of simulations with a common shock
mean(corr_out$shock_indicator)

# -----------------------------
# Plot
# -----------------------------
library(ggplot2)

ggplot(
  data.frame(
    loss = c(agg_bi_base, agg_bi_corr),
    scenario = rep(c("Baseline", "Correlated"), each = length(agg_bi_base))
  ),
  aes(x = loss)
) +
  geom_histogram(bins = 50, fill = "lightblue", color = "black") +
  facet_wrap(~scenario, scales = "free_y") +
  labs(
    title = "Business Interruption Aggregate Loss: Baseline vs Correlated Scenario",
    x = "Aggregate Net Loss",
    y = "Count"
  ) +
  theme_minimal()



