# =====================================================================
#  Prepare a local annual OMIE functional dataset (2025)
#  Run from the omie2fdata package root after installing/loading the package.
#
#  The derived object is deliberately written under dev/derived/ rather than
#  data/. OMIE clearly permits reuse of public/free information when its
#  original content is respected, but its legal notice is not an explicit
#  open-data licence for redistribution of transformed datasets. Keep this
#  derived object local unless redistribution terms are clarified with OMIE.
# =====================================================================

library(omie2fdata)

# Option A: point to one or more folders/files already downloaded with
# omie2txt(), for example:
# input <- c("../data_omie_1998_2025", "../data_omie_hour")
#
# Option B: leave NULL and download 2025 once into dev/raw/omie2025.
input <- NULL
raw_dir <- file.path("dev", "raw", "omie2025")

if (is.null(input)) {
  dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
  input <- omie2txt(
    start_date = "2025-01-01",
    end_date = "2025-12-31",
    resolution = "hour",
    output_dir = raw_dir,
    verbose = TRUE,
    control = list(max_attempts = 3, retry_wait = 2)
  )
}

omie2025 <- omie2ldata(
  start_date = "2025-01-01",
  end_date = "2025-12-31",
  var_names = c("price_es", "buy_es"),
  resolution = "hour",
  source = "results",
  file = input,
  verbose = TRUE
)

stopifnot(inherits(omie2025, "ldata"), nrow(omie2025$df) == 365L)

omie2025$df$weekday <- weekdays(as.Date(omie2025$df$date))
omie2025$df$weekend <- as.POSIXlt(as.Date(omie2025$df$date))$wday %in% c(0L, 6L)
omie2025$df$blackout <- as.Date(omie2025$df$date) == as.Date("2025-04-28")

attr(omie2025, "source") <- "OMI-Polo Español, S.A. (OMIE)"
attr(omie2025, "source_url") <- "https://www.omie.es/"
attr(omie2025, "source_period") <- c("2025-01-01", "2025-12-31")
attr(omie2025, "retrieved_on") <- as.character(Sys.Date())
attr(omie2025, "transformations") <- c(
  "Daily curves represented on a common 24-point hourly grid.",
  "Historical hourly MWh purchase values are represented numerically as average MW over one hour.",
  "DST days are normalized to 24 points according to omie2fdata rules."
)

derived_dir <- file.path("dev", "derived")
dir.create(derived_dir, recursive = TRUE, showWarnings = FALSE)
saveRDS(omie2025, file.path(derived_dir, "omie2025.rds"), compress = "xz")

message("Created dev/derived/omie2025.rds with ", nrow(omie2025$df),
        " daily curves (local derived data; not package data).")
