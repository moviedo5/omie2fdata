# Compare consolidated results and marginalpdbc on identical dates --------
# Run after dev/download_marginal_examples.R.

if (!requireNamespace("devtools", quietly = TRUE)) {
  stop("Package 'devtools' is required for this development script.")
}
devtools::load_all(".")

first_dir <- function(...) {
  x <- c(...)
  ok <- dir.exists(x)
  if (!any(ok)) stop("None of these directories exists: ", paste(x, collapse = ", "))
  x[which(ok)[1L]]
}

# Prefer bundled examples when present; otherwise use the original local
# directories beside the package source tree.
results_apr <- first_dir(
  file.path("inst", "extdata", "results_apr2025"),
  file.path("..", "data_omie_apr2025")
)
results_q <- first_dir(
  file.path("inst", "extdata", "results_15min"),
  file.path("..", "data_omie_15min")
)
marg_apr <- file.path("dev", "list_examples", "marginalpdbc_apr2025")
marg_q <- file.path("dev", "list_examples", "marginalpdbc_15min")

stopifnot(dir.exists(marg_apr), dir.exists(marg_q))

r1 <- omie2df("2025-04-26", "2025-04-30", "price_es", "hour",
              source = "results", file = results_apr)
m1 <- omie2df("2025-04-26", "2025-04-30", "price_es", "hour",
              source = "marginalpdbc", file = marg_apr)

r2 <- omie2df("2025-10-01", "2025-10-03", "price_es", "15min",
              source = "results", file = results_q)
m2 <- omie2df("2025-10-01", "2025-10-03", "price_es", "15min",
              source = "marginalpdbc", file = marg_q)

cmp <- data.frame(
  example = c("2025-04-26/30 hourly", "2025-10-01/03 15min"),
  n_results = c(nrow(r1), nrow(r2)),
  n_marginal = c(nrow(m1), nrow(m2)),
  max_abs_diff = c(
    max(abs(r1$price_es - m1$price_es), na.rm = TRUE),
    max(abs(r2$price_es - m2$price_es), na.rm = TRUE)
  )
)
print(cmp, row.names = FALSE)

invisible(list(
  hour = list(results = r1, marginalpdbc = m1),
  quarter = list(results = r2, marginalpdbc = m2),
  comparison = cmp
))
