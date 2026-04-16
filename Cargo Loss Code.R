install.packages("readxl")
install.packages("fitdistrplus")
library(readxl)
library(dplyr)
library(fitdistrplus)

set.seed(2026)

freq_df <- read_excel("srcsc-2026-claims-cargo.xlsx", sheet = "freq")
sev_df <- read_excel("srcsc-2026-claims-cargo.xlsx", sheet = "sev")

## Cleaning frequency data 
freq_df %>%
  dplyr::select(policy_id, shipment_id, cargo_type, cargo_value, weight, 
                route_risk, distance, transit_duration, pilot_experience,
                vessel_age, container_type, solar_radiation, debris_density, 
                exposure, claim_count) %>%
  summary()

freq_df <- na.omit(freq_df)
freq_df <- freq_df[freq_df$cargo_value >= 0 & freq_df$cargo_value <= 680000000, ]
freq_df <- freq_df[freq_df$weight >= 0 & freq_df$weight <= 250000, ]
freq_df <- freq_df[freq_df$debris_density >= 0 & freq_df$debris_density <= 1, ]
freq_df <- freq_df[freq_df$route_risk %in% c(1, 2, 3, 4, 5), ]
freq_df <- freq_df[freq_df$distance >= 1 & freq_df$distance <= 100, ]
freq_df <- freq_df[freq_df$transit_duration >= 1 & freq_df$transit_duration <= 60, ]
freq_df <- freq_df[freq_df$pilot_experience >= 1 & freq_df$pilot_experience <= 30, ]
freq_df <- freq_df[freq_df$vessel_age >= 1 & freq_df$vessel_age <= 50, ]
freq_df <- freq_df[freq_df$solar_radiation >= 0 & freq_df$solar_radiation <= 1, ]
freq_df <- freq_df[freq_df$debris_density >= 0 & freq_df$debris_density <= 1, ]
freq_df <- freq_df[freq_df$exposure >= 0 & freq_df$exposure <= 1, ]
freq_df <- freq_df[freq_df$claim_count >= 0 & freq_df$claim_count <= 5 & freq_df$claim_count == floor(freq_df$claim_count), ]

## Cleaning severity data
sev_df %>%
  dplyr::select(claim_id, claim_seq, policy_id, shipment_id, cargo_type, cargo_value, weight, 
         route_risk, distance, transit_duration, pilot_experience,
         vessel_age, container_type, solar_radiation, debris_density, exposure, 
         claim_amount) %>%
  summary()

sev_df <- na.omit(sev_df)
sev_df <- sev_df[sev_df$claim_seq > 0 & sev_df$claim_seq == floor(sev_df$claim_seq), ]
sev_df <- sev_df[sev_df$cargo_value >= 0 & sev_df$cargo_value <= 680000000, ]
sev_df <- sev_df[sev_df$weight >= 0 & sev_df$weight <= 250000, ]
sev_df <- sev_df[sev_df$debris_density >= 0 & sev_df$debris_density <= 1, ]
sev_df <- sev_df[sev_df$route_risk %in% c(1, 2, 3, 4, 5), ]
sev_df <- sev_df[sev_df$distance >= 1 & sev_df$distance <= 100, ]
sev_df <- sev_df[sev_df$transit_duration >= 1 & sev_df$transit_duration <= 60, ]
sev_df <- sev_df[sev_df$pilot_experience >= 1 & sev_df$pilot_experience <= 30, ]
sev_df <- sev_df[sev_df$vessel_age >= 1 & sev_df$vessel_age <= 50, ]
sev_df <- sev_df[sev_df$solar_radiation >= 0 & sev_df$solar_radiation <= 1, ]
sev_df <- sev_df[sev_df$debris_density >= 0 & sev_df$debris_density <= 1, ]
sev_df <- sev_df[sev_df$exposure >= 0 & sev_df$exposure <= 1, ]
sev_df <- sev_df[sev_df$claim_amount >= 0 & sev_df$claim_amount <= 678000000, ]

# Exploratory data analysis
total_claims   <- sum(freq_df$claim_count)
total_exposure <- sum(freq_df$exposure)

claim_frequency <- total_claims / total_exposure
claim_frequency

# Average severity
total_loss <- sum(sev_df$claim_amount)
num_claims <- nrow(sev_df)

avg_severity <- total_loss / num_claims
avg_severity

# Loss per exposure
loss_per_exposure <- claim_frequency * avg_severity
loss_per_exposure

# Observed aggregate loss distribution
observed_agg <- sev_df %>%
  group_by(shipment_id) %>%
  summarise(total_loss = sum(claim_amount), .groups = "drop")

hist(observed_agg$total_loss,
     breaks = 50,
     main = "Observed Aggregate Cargo Loss Distribution",
     xlab = "Aggregate Loss per Shipment",
     col = "lightblue")

############################ Claim frequency summary ###########################
mean(freq_df$claim_count)
var(freq_df$claim_count)
length(freq_df$claim_count)

hist(freq_df$claim_count,
     breaks = 5,
     main = "Claim Frequency Distribution",
     xlab = "Claim Count")

######################### Claim severity summary ###############################
hist(sev_df$claim_amount,
     main = "Cargo Loss Severity",
     xlab = "Claim Amount")

sev_df$log_claim <- log(sev_df$claim_amount)

hist(sev_df$log_claim,
     breaks = 50,
     main = "Log Cargo Loss Severity",
     xlab = "Log Claim Amount")

################### Single lognormal fit (for comparison only) #################
lognorm_fit <- fitdist(sev_df$claim_amount, "lnorm")
mu <- lognorm_fit$estimate["meanlog"]
sigma <- lognorm_fit$estimate["sdlog"]

mu
sigma

########################### Bimodal severity model #############################
cutoff <- 15
sev_df$sev_group <- ifelse(sev_df$log_claim < cutoff, "Ordinary", "Catastrophic")

table(sev_df$sev_group)

ordinary <- sev_df$log_claim[sev_df$sev_group == "Ordinary"]
catastrophic <- sev_df$log_claim[sev_df$sev_group == "Catastrophic"]

hist(ordinary,
     breaks = 40,
     col = rgb(0, 0, 1, 0.4),
     probability = TRUE,
     main = "Bimodal Severity Distribution",
     xlab = "Log Claim Amount",
     xlim = range(sev_df$log_claim))

hist(catastrophic,
     breaks = 40,
     col = rgb(1, 0, 0, 0.4),
     probability = TRUE,
     add = TRUE)

fit_ord <- fitdist(sev_df$claim_amount[sev_df$sev_group == "Ordinary"], "lnorm")
fit_cat <- fitdist(sev_df$claim_amount[sev_df$sev_group == "Catastrophic"], "lnorm")

summary(fit_ord)
summary(fit_cat)

p_ord <- mean(sev_df$sev_group == "Ordinary")
p_cat <- mean(sev_df$sev_group == "Catastrophic")

p_ord
p_cat

mu1 <- fit_ord$estimate["meanlog"]
sd1 <- fit_ord$estimate["sdlog"]

mu2 <- fit_cat$estimate["meanlog"]
sd2 <- fit_cat$estimate["sdlog"]

x <- seq(min(sev_df$log_claim), max(sev_df$log_claim), length = 1000)

lines(x, dnorm(x, mean = mu1, sd = sd1), col = "blue", lwd = 2)
lines(x, dnorm(x, mean = mu2, sd = sd2), col = "red", lwd = 2)

########################### Simulated aggregate loss ###########################
lambda <- claim_frequency
n_sim <- 10000

sim_severity <- function(n, p_cat, mu1, sd1, mu2, sd2) {
  group <- rbinom(n, 1, p_cat)  # 1 = catastrophic, 0 = ordinary
  
  losses <- ifelse(
    group == 1,
    rlnorm(n, meanlog = mu2, sdlog = sd2),
    rlnorm(n, meanlog = mu1, sdlog = sd1)
  )
  
  return(losses)
}

sim_agg_loss <- function(lambda, n_sim, p_cat, mu1, sd1, mu2, sd2) {
  aggregate_losses <- numeric(n_sim)
  
  for (i in 1:n_sim) {
    N <- rpois(1, lambda)
    
    if (N > 0) {
      losses <- sim_severity(N, p_cat, mu1, sd1, mu2, sd2)
      aggregate_losses[i] <- sum(losses)
    } else {
      aggregate_losses[i] <- 0
    }
  }
  
  return(aggregate_losses)
}

aggregate_losses <- sim_agg_loss(
  lambda = lambda,
  n_sim = n_sim,
  p_cat = p_cat,
  mu1 = mu1,
  sd1 = sd1,
  mu2 = mu2,
  sd2 = sd2
)

############################# Aggregate loss summary ###########################
mean_loss    <- mean(aggregate_losses)
sd_loss      <- sd(aggregate_losses)
var_loss     <- var(aggregate_losses)
q95          <- quantile(aggregate_losses, 0.95)
q99          <- quantile(aggregate_losses, 0.99)
max_loss_sim <- max(aggregate_losses)

agg_summary <- data.frame(
  Mean_Aggregate_Loss = mean_loss,
  SD_Aggregate_Loss = sd_loss,
  Variance_Aggregate_Loss = var_loss,
  VaR_95 = q95,
  VaR_99 = q99,
  Max_Simulated_Loss = max_loss_sim
)

agg_summary

hist(aggregate_losses,
     breaks = 50,
     main = "Simulated Aggregate Cargo Loss Distribution",
     xlab = "Aggregate Loss",
     col = "lightblue")

############################## Pricing Premiums ################################
expense_ratio <- 0.10
risk_margin   <- 0.15
profit_margin <- 0.05

total_loading <- expense_ratio + risk_margin + profit_margin
base_premium <- mean_loss * (1 + total_loading)

for (route_risk in seq(1:5)) {
  risk_factor <- 1 + 0.10 * (route_risk - 3)
  premium_adjusted <- base_premium * risk_factor
  d <- 0.05 + (route_risk - 1) * 0.0125
  
  print(premium_adjusted)
  print(d * premium_adjusted)
}

############################## Pre + post table ################################
lambda <- claim_frequency
n_sim <- 10000
policy_limit <- 400000000

deductible_rate_fn <- function(route_risk) {
  if (route_risk == 1) return(0.05)
  if (route_risk == 2) return(0.0625)
  if (route_risk == 3) return(0.075)
  if (route_risk == 4) return(0.0875)
  if (route_risk == 5) return(0.10)
  return(0.075)
}

apply_product_claim <- function(claim_amount, cargo_value, route_risk, policy_limit = 400000000) {
  
  deductible_rate <- deductible_rate_fn(route_risk)
  deductible_amount <- deductible_rate * cargo_value
  
  insurer_payment <- max(claim_amount - deductible_amount, 0)
  insurer_payment <- min(insurer_payment, cargo_value, policy_limit)
  
  retained_loss <- claim_amount - insurer_payment
  
  return(retained_loss)
}

simulate_pre_post_base <- function(n_sim = 10000, seed = 2026) {
  set.seed(seed)
  
  gross_losses <- numeric(n_sim)
  retained_losses <- numeric(n_sim)
  
  for (i in 1:n_sim) {
    N <- rpois(1, lambda)
    
    if (N > 0) {
      sampled_claims <- sev_df[sample(1:nrow(sev_df), N, replace = TRUE), ]
      gross_claims <- sampled_claims$claim_amount
      
      gross_losses[i] <- sum(gross_claims)
      
      retained_vec <- numeric(N)
      
      for (j in 1:N) {
        retained_vec[j] <- apply_product_claim(
          claim_amount = gross_claims[j],
          cargo_value = sampled_claims$cargo_value[j],
          route_risk = sampled_claims$route_risk[j],
          policy_limit = policy_limit
        )
      }
      
      retained_losses[i] <- sum(retained_vec)
      
    } else {
      gross_losses[i] <- 0
      retained_losses[i] <- 0
    }
  }
  
  return(list(gross = gross_losses, retained = retained_losses))
}

base_res <- simulate_pre_post_base(n_sim = n_sim, seed = 2026)

pre_post_stats <- data.frame(
  Measure = c("Mean", "Standard deviation", "95th percentile", "99th percentile"),
  
  Before_Product_Gross = c(
    mean(base_res$gross),
    sd(base_res$gross),
    quantile(base_res$gross, 0.95),
    quantile(base_res$gross, 0.99)
  ),
  
  After_Product_Retained_Loss = c(
    mean(base_res$retained),
    sd(base_res$retained),
    quantile(base_res$retained, 0.95),
    quantile(base_res$retained, 0.99)
  )
)

pre_post_stats$Reduction_Percent <- round(
  100 * (pre_post_stats$Before_Product_Gross - pre_post_stats$After_Product_Retained_Loss) /
    pre_post_stats$Before_Product_Gross,
  2
)

pre_post_stats$Before_Product_Gross <- round(pre_post_stats$Before_Product_Gross, 0)
pre_post_stats$After_Product_Retained_Loss <- round(pre_post_stats$After_Product_Retained_Loss, 0)

pre_post_stats

base_res <- simulate_pre_post(lambda_mult = 1.00, sev_mult = 1.00, n_sim = n_sim, seed = 2026)
stress50_res <- simulate_pre_post(lambda_mult = 1.20, sev_mult = 1.25, n_sim = n_sim, seed = 2026)
stress100_res <- simulate_pre_post(lambda_mult = 1.50, sev_mult = 1.75, n_sim = n_sim, seed = 2026)

scenario_table <- data.frame(
  Scenario = c("Base case", "1-in-50 year", "1-in-100 year"),
  Description = c(
    "Attritional claims, no correlated events",
    "20% freq surge + 25% severity increase",
    "50% freq surge + 75% severity increase"
  ),
  Expected_Loss_Before = c(
    mean(base_res$gross),
    mean(stress50_res$gross),
    mean(stress100_res$gross)
  ),
  Expected_Loss_After = c(
    mean(base_res$retained),
    mean(stress50_res$retained),
    mean(stress100_res$retained)
  )
)

scenario_table$Reduction_Percent <- round(
  100 * (scenario_table$Expected_Loss_Before - scenario_table$Expected_Loss_After) /
    scenario_table$Expected_Loss_Before,
  2
)

scenario_table$Expected_Loss_Before <- round(scenario_table$Expected_Loss_Before, 0)
scenario_table$Expected_Loss_After  <- round(scenario_table$Expected_Loss_After, 0)

scenario_table

################################################################################
# Pricing
inflation <- c(3.77,2.32,1.48,1.08,0.22,0.71,1.55,2.16,1.81,0.73,2.94,7.08,5.98,2.76,2.39)
rf1yr <- c(0.24,0.24,0.19,0.17,0.40,0.72,1.42,2.18,2.30,0.43,0.15,2.94,5.45,5.28,4.74)

avg_inflation <- mean(inflation) / 100
avg_rf <- mean(rf1yr) / 100

# Short-term (1 year)
expected_costs_short <- mean(aggregate_losses + expense_ratio * base_premium)
expected_returns_short <- base_premium + base_premium * avg_rf
expected_net_revenue_short <- expected_returns_short - expected_costs_short

# Long-term (5 years)
years <- 5
growth_factor <- (1 + avg_inflation)^years

claims_long <- aggregate_losses * growth_factor
premium_long <- base_premium * growth_factor

expected_costs_long <- mean(claims_long + expense_ratio * premium_long)
expected_returns_long <- premium_long + premium_long * avg_rf
expected_net_revenue_long <- expected_returns_long - expected_costs_long

data.frame(
  Horizon = c("Short-term", "Long-term"),
  Costs = c(expected_costs_short, expected_costs_long),
  Returns = c(expected_returns_short, expected_returns_long),
  Net_Revenue = c(expected_net_revenue_short, expected_net_revenue_long)
)

############################# Scenario Testing #################################
sim_agg_scenario <- function(lambda, n_sim, p_cat, mu1, sd1, mu2, sd2, sev_mult) {
  aggregate_losses <- numeric(n_sim)
  
  for (i in 1:n_sim) {
    N <- rpois(1, lambda)
    
    if (N > 0) {
      losses <- sim_severity(N, p_cat, mu1, sd1, mu2, sd2)
      losses <- losses * sev_mult
      
      aggregate_losses[i] <- sum(losses)
    } else {
      aggregate_losses[i] <- 0
    }
  }
  
  return(aggregate_losses)
}

# Best case
best_case_losses <- sim_agg_scenario(
  lambda = lambda * 0.75,
  n_sim = n_sim,
  p_cat = p_cat,
  mu1 = mu1,
  sd1 = sd1,
  mu2 = mu2,
  sd2 = sd2,
  sev_mult = 1
)


# Moderate case
moderate_case_losses <- sim_agg_scenario(
  lambda = lambda * 1.15,
  n_sim = n_sim,
  p_cat = p_cat,
  mu1 = mu1,
  sd1 = sd1,
  mu2 = mu2,
  sd2 = sd2,
  sev_mult = 1.2
)

worst_case_losses <- sim_agg_scenario(
  lambda = lambda * 2,
  n_sim = n_sim,
  p_cat = p_cat,
  mu1 = mu1,
  sd1 = sd1,
  mu2 = mu2,
  sd2 = sd2,
  sev_mult = 1.5
)

# Expected loss table
scenario_test_table <- data.frame(
  Scenario = c(
    "Best case: smooth operations, attritional only",
    "Moderate case: isolated disruption event",
    "Worst case: catastrophic correlated multi-route failure"
  ),
  Frequency_Impact = c("lambda x 0.75", "lambda x 1.15", "lambda x 2.00"),
  Severity_Impact = c("mu unchanged", "+20% severity", "+50% severity"),
  Expected_Loss_D_Million = c(
    mean(best_case_losses) / 1e6,
    mean(moderate_case_losses) / 1e6,
    mean(worst_case_losses) / 1e6
  )
)

scenario_test_table$Expected_Loss_D_Million <- round(scenario_test_table$Expected_Loss_D_Million, 2)

scenario_test_table
