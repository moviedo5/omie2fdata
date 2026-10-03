#' Download files from the OMIE public file repository
#'
#' Downloads daily files exposed through OMIE's "Acceso a ficheros" repository.
#' This function is deliberately separate from [omie2txt()], which downloads
#' the consolidated daily market-results TXT table.
#'
#' The current implementation supports the common daily naming convention
#' `<file_type>_YYYYMMDD.<version>`. It has been designed for files such as
#' `marginalpdbc` and `curva_pbc`. Other OMIE repository families may use
#' monthly ZIP files or different names and can be added later without changing
#' the functional-data API.
#'
#' @param file_type OMIE repository directory/file prefix, for example
#'   `"marginalpdbc"` or `"curva_pbc"`.
#' @param start_date,end_date Start and end dates.
#' @param output_dir Directory where raw files are kept. If `NULL`, temporary
#'   files are used.
#' @param version File version suffix. Default `1`.
#' @param try_unversioned Logical; if the versioned filename is unavailable,
#'   also try the same filename without `.version`.
#' @param verbose Logical; print progress messages.
#' @param control Advanced download options: `max_attempts`, `retry_wait` and
#'   `overwrite`.
#'
#' @return A named character vector of successfully downloaded local paths.
#' @export
omie2download <- function(file_type = "marginalpdbc", start_date, end_date,
                          output_dir = NULL, version = 1L,
                          try_unversioned = TRUE, verbose = FALSE,
                          control = list()) {
  dd <- .omie_validate_dates(start_date, end_date)
  ctrl <- .omie_control(control)
  if (length(file_type) != 1L || !grepl("^[A-Za-z0-9_]+$", file_type)) {
    stop("'file_type' must be a single OMIE file prefix such as 'marginalpdbc'.")
  }
  if (!is.null(output_dir) && !dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  dates <- seq(dd$start_date, dd$end_date, by = "day")
  out <- character()

  for (i in seq_along(dates)) {
    d <- dates[i]
    ds <- format(d, "%Y-%m-%d")
    stem <- paste0(file_type, "_", format(d, "%Y%m%d"))
    candidates <- paste0(stem, ".", as.integer(version))
    if (isTRUE(try_unversioned)) candidates <- c(candidates, stem)
    success <- FALSE

    for (fname in candidates) {
      url <- paste0(
        "https://www.omie.es/es/file-download?parents=",
        utils::URLencode(file_type, reserved = TRUE),
        "&filename=", utils::URLencode(fname, reserved = TRUE)
      )
      path <- if (is.null(output_dir)) tempfile(pattern = paste0(fname, "_"))
      else file.path(output_dir, fname)
      if (verbose) message("[OMIE] repository: ", fname)
      if (.omie_download_file(url, path, ctrl, verbose = verbose, warn = FALSE)) {
        out[ds] <- path
        success <- TRUE
        break
      }
    }
    if (!success) warning("Could not download OMIE repository file for ", ds,
                          " (", file_type, ").", call. = FALSE)
  }
  out
}
