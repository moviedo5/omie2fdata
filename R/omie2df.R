#' Read or download OMIE data as a data frame
#'
#' Provides the common data layer used by [omie2fdata()] and [omie2ldata()].
#' Data can come from the consolidated daily market-results files (`source =
#' "results"`) or from the direct `marginalpdbc` repository files.
#'
#' @param start_date,end_date Start and end dates.
#' @param var_names Variables to return.
#' @param resolution `"hour"` (default) or `"15min"`.
#' @param source `"results"` or `"marginalpdbc"`.
#' @param file Optional file, vector of files, or directory. If supplied, no
#'   download is performed.
#' @param input_dir Deprecated-compatible alias for a local directory used by
#'   the original package. Do not use together with `file`.
#' @param verbose Logical; print progress messages.
#' @param seed Optional seed retained for compatibility with the original results downloader.
#' @param check_header Logical; validate result-file resolution.
#' @param control Advanced options passed to the download function.
#'
#' @return A `data.frame` with one row per market day and period. Attributes
#'   `metadata`, `units`, `source` and `resolution` contain shared information.
#' @export
omie2df <- function(start_date, end_date,
                    var_names = NULL,
                    resolution = c("hour", "15min"),
                    source = c("results", "marginalpdbc"),
                    file = NULL, input_dir = NULL, verbose = FALSE, seed = NULL,
                    check_header = TRUE, control = list()) {
  req <- .omie_validate_request(start_date, end_date, resolution)
  source <- match.arg(source)
  if (is.null(var_names)) {
    var_names <- if (source == "results") .omie_default_var_names() else c("price_es", "price_pt")
  }
  var_names <- unique(as.character(var_names))
  if (!length(var_names) || anyNA(var_names)) stop("'var_names' must not be empty.")
  supported <- .omie_source_vars(source)
  bad <- setdiff(var_names, supported)
  if (length(bad)) {
    stop("Variable(s) not available for source '", source, "': ",
         paste(bad, collapse = ", "))
  }

  local_files <- .omie_input_files(file, input_dir, source)
  if (!length(local_files)) {
    paths <- if (source == "results") {
      omie2txt(req$start_date, req$end_date, req$resolution,
               output_dir = NULL, verbose = verbose, seed = seed,
               check_header = check_header, control = control)
    } else {
      omie2download("marginalpdbc", req$start_date, req$end_date,
                    output_dir = NULL, verbose = verbose, control = control)
    }
    local_files <- unname(paths)
  }
  if (!length(local_files)) stop("No OMIE files available for the requested period.")

  parsed <- list()
  meta <- list()
  missing_count <- stats::setNames(integer(length(var_names)), var_names)

  for (f in local_files) {
    one <- tryCatch(
      .omie_parse_file(f, source, req$resolution, check_header),
      error = function(e) {
        if (length(file) && !dir.exists(file[1L])) stop(e)
        if (verbose) message("[OMIE] skipping ", basename(f), ": ", conditionMessage(e))
        NULL
      }
    )
    if (is.null(one)) next
    d <- as.Date(one$info$market_date)
    if (is.na(d) || d < req$start_date || d > req$end_date) next
    if (!identical(one$resolution, req$resolution)) next
    ds <- as.character(d)
    if (!is.null(parsed[[ds]])) {
      warning("More than one OMIE file found for ", ds, "; using the first.", call. = FALSE)
      next
    }
    n <- one$n_periods
    vals <- stats::setNames(vector("list", length(var_names)), var_names)
    for (v in var_names) {
      if (!is.null(one$values[[v]])) vals[[v]] <- one$values[[v]]
      else {
        vals[[v]] <- rep(NA_real_, n)
        missing_count[v] <- missing_count[v] + 1L
      }
    }
    parsed[[ds]] <- vals
    meta[[ds]] <- data.frame(
      date = d,
      market_date = d,
      issue_datetime = one$info$issue_datetime,
      resolution = one$resolution,
      raw_resolution = one$raw_resolution,
      n_periods_raw = one$n_periods_raw,
      n_periods = one$n_periods,
      dst_adjusted = one$dst_adjusted,
      dst_type = one$dst_type,
      aggregation = one$aggregation,
      source = source,
      file_type = one$file_type,
      file_path = normalizePath(f, winslash = "/", mustWork = FALSE),
      stringsAsFactors = FALSE
    )
  }
  if (!length(parsed)) stop("No valid OMIE files could be parsed.")

  dates <- sort(as.Date(names(parsed)))
  rows <- lapply(seq_along(dates), function(i) {
    d <- dates[i]
    ds <- as.character(d)
    n <- if (req$resolution == "hour") 24L else 96L
    z <- data.frame(
      date = rep(d, n),
      period = seq_len(n),
      argval = .omie_argvals(req$resolution),
      stringsAsFactors = FALSE
    )
    for (v in var_names) z[[v]] <- parsed[[ds]][[v]]
    z
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  meta_df <- do.call(rbind, meta[as.character(dates)])
  rownames(meta_df) <- as.character(dates)

  miss <- missing_count[missing_count > 0L]
  if (length(miss)) {
    warning("Variable(s) absent in some daily files and filled with NA: ",
            paste(names(miss), miss, sep = " (", collapse = "), "), ")",
            call. = FALSE)
  }
  attr(out, "metadata") <- meta_df
  attr(out, "units") <- .omie_var_units()[var_names]
  attr(out, "source") <- source
  attr(out, "resolution") <- req$resolution
  out
}
