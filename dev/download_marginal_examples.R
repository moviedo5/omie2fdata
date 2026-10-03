# Download direct-repository examples for validation ----------------------
# Run from the omie2fdata package root after devtools::load_all().

if (!requireNamespace("devtools", quietly = TRUE)) {
  stop("Package 'devtools' is required for this development script.")
}
devtools::load_all(".")

base <- file.path("dev", "list_examples")
apr_dir <- file.path(base, "marginalpdbc_apr2025")
q_dir <- file.path(base, "marginalpdbc_15min")
dir.create(apr_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(q_dir, recursive = TRUE, showWarnings = FALSE)

apr <- omie2download(
  file_type = "marginalpdbc",
  start_date = "2025-04-26",
  end_date = "2025-04-30",
  output_dir = apr_dir,
  verbose = TRUE,
  control = list(max_attempts = 3, retry_wait = 5, overwrite = TRUE)
)

q <- omie2download(
  file_type = "marginalpdbc",
  start_date = "2025-10-01",
  end_date = "2025-10-03",
  output_dir = q_dir,
  verbose = TRUE,
  control = list(max_attempts = 3, retry_wait = 5, overwrite = TRUE)
)

cat("\nHourly marginalpdbc files:\n")
print(apr)
cat("\nQuarter-hour marginalpdbc files:\n")
print(q)
