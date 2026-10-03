#' Convert OMIE data to an ldata object
#'
#' Builds a multivariate [fda.usc::ldata] object with one row per market day in
#' `df` and one aligned `fdata` component per requested variable.
#'
#' @param start_date,end_date Start and end dates.
#' @param var_names Variables to include. If `NULL`, defaults depend on the
#'   selected source.
#' @param resolution `"hour"` (default) or `"15min"`.
#' @param input_dir Backward-compatible local-directory argument.
#' @param output_rda Backward-compatible `.rda` output path. Prefer
#'   `output_file` for new code.
#' @param verbose Logical.
#' @param seed Optional seed retained for backward compatibility.
#' @param check_header Logical; validate consolidated result-file resolution.
#' @param source `"results"` (default) or `"marginalpdbc"`.
#' @param df Optional data frame returned by [omie2df()].
#' @param file Optional file, vector of files, or directory.
#' @param output_file Optional `.rds`, `.RData` or `.rda` file. Do not use
#'   together with `output_rda`.
#' @param control Advanced download options.
#'
#' @return An object created with [fda.usc::ldata].
#' @export
omie2ldata <- function(start_date, end_date, var_names = NULL,
                       resolution = c("hour", "15min"),
                       input_dir = NULL, output_rda = NULL,
                       verbose = FALSE, seed = NULL, check_header = TRUE,
                       source = c("results", "marginalpdbc"),
                       df = NULL, file = NULL, output_file = NULL,
                       control = list()) {
  resolution <- match.arg(resolution)
  source <- match.arg(source)
  if (!is.null(output_rda) && !is.null(output_file)) {
    stop("Use only one output: either 'output_rda' or 'output_file'.")
  }
  if (is.null(var_names)) {
    var_names <- if (source == "results") .omie_default_var_names() else c("price_es", "price_pt")
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
  if (is.null(meta)) {
    dates <- sort(unique(as.Date(dat$date)))
    meta <- data.frame(date = dates, stringsAsFactors = FALSE,
                       row.names = as.character(dates))
  }
  lfd <- lapply(var_names, function(v) .omie_fdata_from_df(dat, v, resolution))
  names(lfd) <- var_names
  rownames(meta) <- rownames(lfd[[1L]]$data)
  ans <- fda.usc::ldata(df = meta, mfdata = lfd)

  if (!is.null(output_rda)) {
    e <- new.env(parent = emptyenv())
    assign("omie_ldata", ans, envir = e)
    dir <- dirname(output_rda)
    if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    save(list = "omie_ldata", envir = e, file = output_rda)
  }
  .omie_save_object(ans, output_file, name = "ldata")
  ans
}
