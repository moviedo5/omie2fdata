# Fix local omie2fdata 0.0.2 data/examples and OMIE download encoding
# Run from the omie2fdata package root.

stopifnot(file.exists("DESCRIPTION"))
desc <- read.dcf("DESCRIPTION")
stopifnot(identical(unname(desc[1, "Package"]), "omie2fdata"))

# ----------------------------------------------------------------------
# 1. Populate inst/extdata from the OMIE sibling data directories
# ----------------------------------------------------------------------

omie_root <- normalizePath("..", winslash = "/", mustWork = TRUE)

src_apr <- file.path(omie_root, "data_omie_apr2025")
src_q <- file.path(omie_root, "data_omie_15min")

dst_apr <- file.path("inst", "extdata", "results_apr2025")
dst_q <- file.path("inst", "extdata", "results_15min")

if (!dir.exists(src_apr)) stop("Source directory not found: ", src_apr)
if (!dir.exists(src_q)) stop("Source directory not found: ", src_q)

dir.create(dst_apr, recursive = TRUE, showWarnings = FALSE)
dir.create(dst_q, recursive = TRUE, showWarnings = FALSE)

apr_dates <- seq(as.Date("2025-04-01"), as.Date("2025-04-30"), by = "day")
apr_files <- paste0("omie_", apr_dates, ".txt")

q_dates <- as.Date(c("2025-10-01", "2025-10-02", "2025-10-03"))
q_files <- paste0("omie_", q_dates, "_15min.txt")

copy_checked <- function(files, from, to) {
  src <- file.path(from, files)
  miss <- files[!file.exists(src)]
  if (length(miss)) {
    stop("Missing source file(s): ", paste(miss, collapse = ", "))
  }
  ok <- file.copy(src, file.path(to, files), overwrite = TRUE)
  if (!all(ok)) stop("Could not copy all files to ", to)
}

copy_checked(apr_files, src_apr, dst_apr)
copy_checked(q_files, src_q, dst_q)

cat("OK:", length(list.files(dst_apr, pattern = "\\.txt$")),
    "April files in", dst_apr, "\n")
cat("OK:", length(list.files(dst_q, pattern = "\\.txt$")),
    "quarter-hour files in", dst_q, "\n")

# ----------------------------------------------------------------------
# 2. Fix spurious encoding warnings in .omie_download_file()
#    HTML detection only needs the initial ASCII bytes.
# ----------------------------------------------------------------------

f <- file.path("R", "utils.R")
x <- readLines(f, warn = FALSE, encoding = "UTF-8")
txt <- paste(x, collapse = "\n")

old <- paste(
'      first <- tryCatch(readLines(destfile, n = 1L, warn = FALSE),',
'                        error = function(e) character())',
'      if (!length(first) || !grepl("^\\\\s*<!DOCTYPE|^\\\\s*<html", first[1L],',
'                                    ignore.case = TRUE)) {',
sep = "\n"
)

new <- paste(
'      prefix_raw <- tryCatch(readBin(destfile, what = "raw", n = 32L),',
'                             error = function(e) raw())',
'      prefix <- if (length(prefix_raw)) rawToChar(prefix_raw) else ""',
'      is_html <- grepl("^\\\\s*<!DOCTYPE|^\\\\s*<html", prefix,',
'                       ignore.case = TRUE)',
'      if (!is_html) {',
sep = "\n"
)

if (grepl(old, txt, fixed = TRUE)) {
  txt <- sub(old, new, txt, fixed = TRUE)
  writeLines(strsplit(txt, "\n", fixed = TRUE)[[1L]], f, useBytes = TRUE)
  cat("OK: patched HTML/encoding check in R/utils.R\n")
} else if (any(grepl("prefix_raw <- tryCatch\\(readBin", x))) {
  cat("OK: R/utils.R encoding fix was already present\n")
} else {
  warning("Could not find the expected .omie_download_file() block in R/utils.R; ",
          "data files were copied, but the encoding-warning patch was not applied.")
}

cat("\nNow run:\n")
cat("  devtools::install(upgrade = \"never\")\n")
cat("then verify:\n")
cat('  system.file("extdata", "results_apr2025", package = "omie2fdata")\n')
cat('  system.file("extdata", "results_15min", package = "omie2fdata")\n')
