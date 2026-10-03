#' Download OMIE daily market-results TXT files
#'
#' Downloads the daily OMIE day-ahead market-results file used by the original
#' `omie2fdata` workflow. Hourly resolution is the default. Quarter-hourly
#' files are available from 2025-10-01 onward.
#'
#' @param start_date,end_date Start and end dates.
#' @param resolution Either `"hour"` (default) or `"15min"`.
#' @param output_dir Directory where raw files are kept. If `NULL`, temporary
#'   files are used.
#' @param verbose Logical; print progress messages.
#' @param seed Optional seed retained for backward compatibility. If supplied,
#'   the download order is randomized reproducibly.
#' @param check_header Logical; validate the downloaded period header.
#' @param control Advanced download options: `max_attempts`, `retry_wait` and
#'   `overwrite`.
#'
#' @return A named character vector of successfully downloaded local paths.
#' @export
omie2txt <- function(start_date, end_date,
                     resolution = c("hour", "15min"),
                     output_dir = NULL, verbose = FALSE, seed = NULL,
                     check_header = TRUE, control = list()) {
  req <- .omie_validate_request(start_date, end_date, resolution)
  ctrl <- .omie_control(control)
  dates <- seq(req$start_date, req$end_date, by = "day")
  if (!is.null(seed)) {
    set.seed(seed)
    dates <- sample(dates)
  }
  if (!is.null(output_dir) && !dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  build_url <- function(d) {
    yy <- format(d, "%Y"); mm <- format(d, "%m"); dd <- format(d, "%d")
    stem <- if (req$resolution == "hour") {
      if (d < .omie_quarter_start()) "INT_PBC_EV_H_1" else "INT_PBC_EV_H_1_60M"
    } else "INT_PBC_EV_H_1"
    paste0("https://www.omie.es/sites/default/files/dados/AGNO_", yy,
           "/MES_", mm, "/TXT/", stem, "_", dd, "_", mm, "_", yy,
           "_", dd, "_", mm, "_", yy, ".TXT")
  }

  dest <- function(d) {
    nm <- paste0("omie_", format(d, "%Y-%m-%d"), "_", req$resolution, ".txt")
    if (is.null(output_dir)) tempfile(pattern = paste0(nm, "_"), fileext = ".txt")
    else file.path(output_dir, nm)
  }

  out <- character()
  for (i in seq_along(dates)) {
    d <- dates[i]
    ds <- format(d, "%Y-%m-%d")
    path <- dest(d)
    if (verbose) message("[OMIE] market results: ", ds, " (", req$resolution, ")")
    if (!.omie_download_file(build_url(d), path, ctrl, verbose = verbose)) next
    if (check_header) {
      ok <- tryCatch({
        x <- .omie_parse_results(path, req$resolution, check_header = TRUE)
        identical(x$resolution, req$resolution)
      }, error = function(e) FALSE)
      if (!ok) {
        warning("Unexpected OMIE results format for ", ds, ": ", path,
                call. = FALSE)
        next
      }
    }
    out[ds] <- path
  }
  out
}
