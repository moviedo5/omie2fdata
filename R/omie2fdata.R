#' Convert OMIE data to functional data
#'
#' Reads local OMIE files or downloads them internally and returns one or more
#' [fda.usc::fdata] objects. `source = "results"` uses the consolidated daily
#' OMIE market-results table; `source = "marginalpdbc"` uses the direct public
#' repository price files. Both sources are normalized to the same functional
#' representation.
#'
#' @param start_date,end_date Start and end dates.
#' @param var_names Variables to convert. If `NULL`, the historical default
#'   (`price_es`, `buy_es`, `sell_es`) is used for `source = "results"`; for
#'   `source = "marginalpdbc"`, `price_es` is used.
#' @param resolution `"hour"` (default) or `"15min"`.
#' @param input_dir Backward-compatible local-directory argument.
#' @param output_dir Backward-compatible directory in which one `.rda` file is
#'   written per requested variable. Prefer `output_file` for new code.
#' @param verbose Logical.
#' @param seed Optional seed retained for backward compatibility with the
#'   original download workflow.
#' @param check_header Logical; validate consolidated result-file resolution.
#' @param source `"results"` (default) or `"marginalpdbc"`.
#' @param df Optional data frame returned by [omie2df()]. If supplied, files
#'   are not read or downloaded.
#' @param file Optional file, vector of files, or directory.
#' @param output_file Optional `.rds`, `.RData` or `.rda` file containing the
#'   returned object. Do not use together with `output_dir`.
#' @param control Advanced download options.
#'
#' @return A single `fdata` object when one variable is requested. For backward
#'   compatibility, requesting several variables returns a named list of
#'   `fdata` objects; [omie2ldata()] is recommended for multivariate data.
#'
#' @examples
#' \dontrun{
#' x <- omie2fdata(
#'   start_date = "2025-10-01", end_date = "2025-10-05",
#'   var_names = "price_es", resolution = "hour"
#' )
#' plot(x)
#'
#' # Same functional variable from direct MARGINALPDBC files
#' x2 <- omie2fdata(
#'   start_date = "2026-07-01", end_date = "2026-07-31",
#'   var_names = "price_es", resolution = "15min",
#'   source = "marginalpdbc"
#' )
#' }
#' @export
omie2fdata <- function(start_date, end_date, var_names = NULL,
                       resolution = c("hour", "15min"),
                       input_dir = NULL, output_dir = NULL,
                       verbose = FALSE, seed = NULL, check_header = TRUE,
                       source = c("results", "marginalpdbc"),
                       df = NULL, file = NULL, output_file = NULL,
                       control = list()) {
  resolution <- match.arg(resolution)
  source <- match.arg(source)
  if (!is.null(output_dir) && !is.null(output_file)) {
    stop("Use only one output: either 'output_dir' or 'output_file'.")
  }
  if (is.null(var_names)) {
    var_names <- if (source == "results") .omie_default_var_names() else "price_es"
  }
  var_names <- unique(as.character(var_names))
  if (!length(var_names) || anyNA(var_names)) stop("'var_names' must not be empty.")

  if (is.null(df)) {
    dat <- omie2df(
      start_date = start_date, end_date = end_date, var_names = var_names,
      resolution = resolution, source = source, file = file,
      input_dir = input_dir, verbose = verbose, seed = seed,
      check_header = check_header, control = control
    )
  } else {
    if (!is.data.frame(df)) stop("'df' must be a data.frame returned by omie2df().")
    dat <- df
    res_attr <- attr(dat, "resolution")
    if (!is.null(res_attr) && !identical(res_attr, resolution)) {
      stop("'df' resolution does not match the requested resolution.")
    }
  }

  bad <- setdiff(var_names, names(dat))
  if (length(bad)) stop("Variable(s) not found in data: ", paste(bad, collapse = ", "))
  meta <- attr(dat, "metadata")
  out <- lapply(var_names, function(v) {
    fd <- .omie_fdata_from_df(dat, v, resolution)
    attr(fd, "df") <- meta
    fd
  })
  names(out) <- var_names

  if (!is.null(output_dir)) {
    if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
    dd <- .omie_validate_dates(start_date, end_date)
    for (v in names(out)) {
      obj_name <- paste0("fd_", v)
      e <- new.env(parent = emptyenv())
      assign(obj_name, out[[v]], envir = e)
      save(list = obj_name, envir = e,
           file = file.path(output_dir,
                            paste0(v, "_", resolution, "_",
                                   format(dd$start_date, "%Y%m%d"), "_",
                                   format(dd$end_date, "%Y%m%d"), ".rda")))
    }
  }

  ans <- if (length(out) == 1L) out[[1L]] else {
    class(out) <- c("omie_fdata_list", "list")
    attr(out, "df") <- meta
    out
  }
  .omie_save_object(ans, output_file, name = "fd")
  ans
}
