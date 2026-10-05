# =============================================================================
# 01_simulate_data.R
# Generates a realistic, visitor-level A/B test dataset for an online
# "Excel: Beginner to Advanced" course landing page.
#
#   Version A (control)   : current landing page
#   Version B (treatment) : redesigned page — student testimonials above the
#                           fold, a shorter sign-up form and a clearer CTA
#
# The data is synthetic (so it can be shared publicly) but built with the
# messiness of real traffic: weekday/weekend swings, device and channel mix,
# skewed order values, and segment-level differences in the treatment effect.
# =============================================================================

set.seed(182)

n_days      <- 28
start_date  <- as.Date("2026-08-03")
daily_mean  <- 1050                      # average visitors per day

dates  <- start_date + 0:(n_days - 1)
wkend  <- weekdays(dates) %in% c("Saturday", "Sunday")
daily_n <- rpois(n_days, ifelse(wkend, daily_mean * 0.7, daily_mean * 1.1))

visitors <- data.frame(
  date = rep(dates, times = daily_n)
)
n <- nrow(visitors)

visitors$visitor_id <- sprintf("V%06d", seq_len(n))
visitors$variant    <- sample(c("A", "B"), n, replace = TRUE)   # 50/50 split
visitors$device     <- sample(c("Mobile", "Desktop", "Tablet"), n,
                              replace = TRUE, prob = c(0.58, 0.35, 0.07))
visitors$source     <- sample(c("Organic search", "Paid social", "Email", "Referral"),
                              n, replace = TRUE, prob = c(0.38, 0.32, 0.18, 0.12))
visitors$new_visitor <- rbinom(n, 1, 0.72)

# ---- Conversion model (log-odds) -------------------------------------------
base_logit <- qlogis(0.030)

device_eff <- c(Mobile = -0.25, Desktop = 0.30, Tablet = 0.00)
source_eff <- c("Organic search" = 0.00, "Paid social" = -0.35,
                "Email" = 0.55, "Referral" = 0.20)

# The redesign helps most on mobile (shorter form), barely on desktop
treat_eff <- c(Mobile = 0.26, Desktop = 0.06, Tablet = 0.15)

wkend_v <- weekdays(visitors$date) %in% c("Saturday", "Sunday")

lp <- base_logit +
  device_eff[visitors$device] +
  source_eff[visitors$source] +
  -0.15 * visitors$new_visitor +
  -0.10 * wkend_v +
  ifelse(visitors$variant == "B", treat_eff[visitors$device], 0)

visitors$converted <- rbinom(n, 1, plogis(lp))

# ---- Order value (right-skewed: Standard vs Pro bundle) --------------------
# Standard course = $49, Pro bundle (course + templates + live Q&A) = $129
p_pro <- ifelse(visitors$variant == "B", 0.27, 0.30)  # B nudges a few to Standard
is_pro <- rbinom(n, 1, p_pro)
visitors$revenue <- ifelse(visitors$converted == 1,
                           ifelse(is_pro == 1, 129, 49), 0)

visitors <- visitors[, c("visitor_id", "date", "variant", "device", "source",
                         "new_visitor", "converted", "revenue")]

dir.create("data", showWarnings = FALSE)
write.csv(visitors, "data/ab_test_landing_page.csv", row.names = FALSE)

cat("Rows written:", nrow(visitors), "\n")
print(aggregate(cbind(converted, revenue) ~ variant, visitors, mean))
