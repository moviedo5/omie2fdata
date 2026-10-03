# Internal helpers for omie2fdata -----------------------------------------

.omie_quarter_start <- function() as.Date("2025-10-01")

.omie_default_var_names <- function() c("price_es", "buy_es", "sell_es")

.omie_var_dictionary <- function() {
  list(
    price_es = c(
      "precio marginal en el sistema espanol",
      "precio marginal"
    ),
    price_pt = c("precio marginal en el sistema portugues"),
    buy_es = c(
      "energia total de compra sistema espanol",
      "potencia total de compra sistema espanol"
    ),
    sell_es = c(
      "energia total de venta sistema espanol",
      "potencia total de venta sistema espanol"
    ),
    buy_pt = c(
      "energia total de compra sistema portugues",
      "potencia total de compra sistema portugues"
    ),
    sell_pt = c(
      "energia total de venta sistema portugues",
      "potencia total de venta sistema portugues"
    ),
    iberian_total = c(
      "energia total del mercado iberico",
      "potencia total del mercado iberico"
    ),
    iberian_total_bilateral = c(
      "energia total con bilaterales del mercado iberico",
      "potencia total con bilaterales del mercado iberico",
      "potencia del mercado iberico incluyendo bilaterales"
    ),
    import_es_from_pt = c("importacion de espana desde portugal"),
    export_es_to_pt = c("exportacion de espana a portugal"),
    demand_es = c("demanda+bombeos", "demanda + bombeos")
  )
}

.omie_var_units <- function() {
  c(
    price_es = "EUR/MWh",
    price_pt = "EUR/MWh",
    buy_es = "MW",
    sell_es = "MW",
    buy_pt = "MW",
    sell_pt = "MW",
    iberian_total = "MW",
    iberian_total_bilateral = "MW",
    import_es_from_pt = "MW",
    export_es_to_pt = "MW",
    demand_es = "MW"
  )
}

.omie_validate_dates <- function(start_date, end_date) {
  start_date <- as.Date(start_date)
  end_date <- as.Date(end_date)
  if (length(start_date) != 1L || length(end_date) != 1L ||
      is.na(start_date) || is.na(end_date)) {
    stop("'start_date' and 'end_date' must be valid dates in 'YYYY-MM-DD' format.")
  }
  if (start_date > end_date) {
    stop("'start_date' must be less than or equal to 'end_date'.")
  }
  list(start_date = start_date, end_date = end_date)
}

.omie_validate_request <- function(start_date, end_date,
                                   resolution = c("hour", "15min")) {
  dd <- .omie_validate_dates(start_date, end_date)
  resolution <- match.arg(resolution)
  if (resolution == "15min" && dd$start_date < .omie_quarter_start()) {
    stop("Resolution '15min' is only available from 2025-10-01 onward.")
  }
  c(dd, list(resolution = resolution))
}

.omie_control <- function(control = list()) {
  defaults <- list(max_attempts = 2L, retry_wait = 2, overwrite = FALSE)
  if (!is.list(control)) stop("'control' must be a list.")
  out <- utils::modifyList(defaults, control)
  out$max_attempts <- as.integer(out$max_attempts)
  out$retry_wait <- as.numeric(out$retry_wait)
  out$overwrite <- isTRUE(out$overwrite)
  if (is.na(out$max_attempts) || out$max_attempts < 1L) {
    stop("'control$max_attempts' must be >= 1.")
  }
  if (is.na(out$retry_wait) || out$retry_wait < 0) {
    stop("'control$retry_wait' must be >= 0.")
  }
  out
}

.omie_norm_label <- function(x) {
  x <- enc2utf8(x)
  x <- iconv(x, from = "", to = "ASCII//TRANSLIT")
  x <- tolower(trimws(x))
  x <- gsub("\\([^)]*\\)", "", x)
  x <- gsub("\\s+", " ", x)
  trimws(x)
}

.omie_match_var <- function(raw_label) {
  lab <- .omie_norm_label(raw_label)
  dict <- .omie_var_dictionary()
  for (nm in names(dict)) {
    if (lab %in% dict[[nm]]) return(nm)
  }
  NA_character_
}

.omie_detect_unit <- function(label) {
  m <- regmatches(label, regexpr("\\([^)]*\\)", label))
  if (!length(m) || is.na(m) || !nzchar(m)) return(NA_character_)
  sub("^\\(|\\)$", "", m)
}

.omie_clean_number_eu <- function(x) {
  x <- trimws(as.character(x))
  x[x == ""] <- NA_character_
  has_comma <- grepl(",", x, fixed = TRUE)
  x[has_comma] <- gsub(".", "", x[has_comma], fixed = TRUE)
  x[has_comma] <- gsub(",", ".", x[has_comma], fixed = TRUE)
  suppressWarnings(as.numeric(x))
}

.omie_clean_number_dot <- function(x) {
  x <- trimws(as.character(x))
  x[x == ""] <- NA_character_
  suppressWarnings(as.numeric(x))
}

.omie_read_lines <- function(file) {
  out <- tryCatch(readLines(file, encoding = "latin1", warn = FALSE),
                  error = function(e) NULL)
  if (is.null(out)) out <- readLines(file, encoding = "UTF-8", warn = FALSE)
  sub("^\\ufeff", "", out)
}

.omie_download_file <- function(url, destfile, ctrl, verbose = FALSE,
                                warn = TRUE) {
  if (file.exists(destfile) && !ctrl$overwrite && file.info(destfile)$size > 0L) {
    return(TRUE)
  }
  dir <- dirname(destfile)
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)

  last_msg <- NULL
  for (attempt in seq_len(ctrl$max_attempts)) {
    ok <- tryCatch({
      status <- suppressWarnings(utils::download.file(
        url = url, destfile = destfile, quiet = !verbose, mode = "wb"
      ))
      identical(status, 0L) || identical(status, 0)
    }, error = function(e) {
      last_msg <<- conditionMessage(e)
      FALSE
    })

    if (ok && file.exists(destfile) && file.info(destfile)$size > 0L) {
      prefix_raw <- tryCatch(readBin(destfile, what = "raw", n = 32L),
                             error = function(e) raw())
      prefix <- if (length(prefix_raw)) rawToChar(prefix_raw) else ""
      is_html <- grepl("^\\s*<!DOCTYPE|^\\s*<html", prefix,
                       ignore.case = TRUE)
      if (!is_html) {
        return(TRUE)
      }
    }
    if (file.exists(destfile)) unlink(destfile)
    if (attempt < ctrl$max_attempts && ctrl$retry_wait > 0) {
      Sys.sleep(ctrl$retry_wait)
    }
  }
  if (warn) {
    warning("Could not download: ", url,
            if (!is.null(last_msg)) paste0(" (", last_msg, ")") else "",
            call. = FALSE)
  }
  FALSE
}

.omie_extract_results_header <- function(lines, file_path = NA_character_) {
  nonempty <- lines[nzchar(trimws(lines))]
  first <- if (length(nonempty)) nonempty[1L] else NA_character_
  issue_datetime <- as.POSIXct(NA_real_, origin = "1970-01-01",
                               tz = "Europe/Madrid")
  market_date <- as.Date(NA_character_)

  if (!is.na(first)) {
    issue_match <- regmatches(
      first,
      regexpr("Fecha Emisi.n *: *[0-9]{2}/[0-9]{2}/[0-9]{4} *- *[0-9]{2}:[0-9]{2}",
              first, perl = TRUE)
    )
    if (length(issue_match) && !is.na(issue_match) && nzchar(issue_match)) {
      issue_txt <- sub(".*: *", "", issue_match)
      issue_datetime <- as.POSIXct(issue_txt, format = "%d/%m/%Y - %H:%M",
                                   tz = "Europe/Madrid")
    }
    parts <- strsplit(first, ";", fixed = TRUE)[[1L]]
    if (length(parts) >= 4L) {
      cand <- trimws(parts[4L])
      if (grepl("^[0-9]{2}/[0-9]{2}/[0-9]{4}$", cand)) {
        market_date <- as.Date(cand, format = "%d/%m/%Y")
      }
    }
  }
  list(issue_datetime = issue_datetime, market_date = market_date,
       file_path = file_path)
}

.omie_period_info <- function(n_raw) {
  if (n_raw %in% c(23L, 24L, 25L)) {
    return(list(raw_resolution = "hour", target = 24L))
  }
  if (n_raw %in% c(92L, 96L, 100L)) {
    return(list(raw_resolution = "15min", target = 96L))
  }
  stop("Unexpected number of OMIE periods: ", n_raw,
       ". Expected 23/24/25 or 92/96/100.")
}

.omie_dst_type <- function(n_raw, target) {
  if (n_raw < target) "spring_forward" else if (n_raw > target) "fall_back" else "none"
}

.omie_adjust_periods <- function(x, resolution) {
  if (resolution == "hour") {
    if (length(x) == 24L) return(x)
    if (length(x) == 23L) {
      return(append(x, mean(x[2:3], na.rm = TRUE), after = 2L))
    }
    if (length(x) == 25L) {
      out <- x
      out[3L] <- mean(out[3:4], na.rm = TRUE)
      return(out[-4L])
    }
  }
  if (resolution == "15min") {
    if (length(x) == 96L) return(x)
    if (length(x) == 92L) {
      ins <- x[8L] + (x[9L] - x[8L]) * (1:4) / 5
      return(c(x[1:8], ins, x[9:92]))
    }
    if (length(x) == 100L) {
      rep_block <- c(
        mean(c(x[9], x[13]), na.rm = TRUE),
        mean(c(x[10], x[14]), na.rm = TRUE),
        mean(c(x[11], x[15]), na.rm = TRUE),
        mean(c(x[12], x[16]), na.rm = TRUE)
      )
      return(c(x[1:8], rep_block, x[17:100]))
    }
  }
  NULL
}

.omie_standardize_values <- function(x, var_name, raw_unit, resolution) {
  unit <- tolower(iconv(ifelse(is.na(raw_unit), "", raw_unit),
                        from = "", to = "ASCII//TRANSLIT"))
  if (var_name %in% c("price_es", "price_pt")) {
    if (grepl("cent/kwh", unit, fixed = TRUE)) x <- x * 10
    return(x)
  }
  if (var_name %in% names(.omie_var_units())[-c(1, 2)]) {
    if (grepl("mwh", unit, fixed = TRUE) && resolution == "15min") x <- x * 4
    return(x)
  }
  x
}

.omie_parse_results <- function(file, requested_resolution = c("hour", "15min"),
                                check_header = TRUE) {
  requested_resolution <- match.arg(requested_resolution)
  lines <- .omie_read_lines(file)
  info <- .omie_extract_results_header(lines, file)
  idx <- which(grepl("^\\s*;\\s*(1|H1Q1)\\s*;", lines, perl = TRUE))[1L]
  if (is.na(idx)) stop("Could not locate the OMIE period header in: ", file)

  split_lines <- strsplit(lines, ";", fixed = TRUE)
  cols <- trimws(split_lines[[idx]][-1L])
  cols <- cols[nzchar(cols)]
  n_raw <- length(cols)
  pinfo <- .omie_period_info(n_raw)
  detected <- if (any(grepl("Q", cols, fixed = TRUE))) "15min" else "hour"
  if (detected != pinfo$raw_resolution) detected <- pinfo$raw_resolution
  if (check_header && detected != requested_resolution) {
    stop("Header resolution mismatch in '", basename(file), "': requested '",
         requested_resolution, "', detected '", detected, "'.")
  }

  values <- list()
  if (idx < length(split_lines)) {
    for (i in seq.int(idx + 1L, length(split_lines))) {
      row <- split_lines[[i]]
      if (!length(row)) next
      raw_label <- trimws(row[1L])
      if (!nzchar(raw_label)) next
      var_name <- .omie_match_var(raw_label)
      if (is.na(var_name)) next
      z <- row[-1L]
      z <- z[seq_len(min(length(z), n_raw))]
      z <- .omie_clean_number_eu(z)
      z <- .omie_adjust_periods(z, detected)
      if (is.null(z) || length(z) != pinfo$target) {
        stop("Could not normalize periods for '", var_name,
             "' in '", basename(file), "'.")
      }
      z <- .omie_standardize_values(z, var_name, .omie_detect_unit(raw_label), detected)
      values[[var_name]] <- z
    }
  }

  list(
    info = info,
    values = values,
    raw_resolution = detected,
    resolution = detected,
    n_periods_raw = n_raw,
    n_periods = pinfo$target,
    dst_adjusted = n_raw != pinfo$target,
    dst_type = .omie_dst_type(n_raw, pinfo$target),
    aggregation = "none",
    file_type = "INT_PBC_EV_H"
  )
}

.omie_parse_marginalpdbc <- function(file,
                                     requested_resolution = c("hour", "15min")) {
  requested_resolution <- match.arg(requested_resolution)
  lines <- .omie_read_lines(file)
  lines <- lines[nzchar(trimws(lines))]
  if (!length(lines) || !grepl("^MARGINALPDBC;", toupper(trimws(lines[1L])))) {
    stop("File does not look like an OMIE MARGINALPDBC file: ", file)
  }
  rows <- lines[-1L]
  rows <- rows[trimws(rows) != "*"]
  spl <- strsplit(rows, ";", fixed = TRUE)
  ok <- lengths(spl) >= 6L
  spl <- spl[ok]
  if (!length(spl)) stop("No MARGINALPDBC records found in: ", file)

  get <- function(j) vapply(spl, function(z) trimws(z[j]), character(1))
  dat <- data.frame(
    year = as.integer(get(1)), month = as.integer(get(2)), day = as.integer(get(3)),
    period = as.integer(get(4)), price_pt = .omie_clean_number_dot(get(5)),
    price_es = .omie_clean_number_dot(get(6)), stringsAsFactors = FALSE
  )
  dat <- dat[order(dat$period), , drop = FALSE]
  dates <- unique(as.Date(sprintf("%04d-%02d-%02d", dat$year, dat$month, dat$day)))
  if (length(dates) != 1L || is.na(dates)) {
    stop("Expected one market date in MARGINALPDBC file: ", file)
  }
  n_raw <- nrow(dat)
  pinfo <- .omie_period_info(n_raw)
  raw_res <- pinfo$raw_resolution
  if (requested_resolution == "15min" && raw_res != "15min") {
    stop("Quarter-hourly values are not available in this MARGINALPDBC file.")
  }

  pt <- .omie_adjust_periods(dat$price_pt, raw_res)
  es <- .omie_adjust_periods(dat$price_es, raw_res)
  if (is.null(pt) || is.null(es)) stop("Could not normalize MARGINALPDBC periods.")
  aggregation <- "none"
  out_res <- raw_res
  if (requested_resolution == "hour" && raw_res == "15min") {
    pt <- rowMeans(matrix(pt, ncol = 4L, byrow = TRUE), na.rm = TRUE)
    es <- rowMeans(matrix(es, ncol = 4L, byrow = TRUE), na.rm = TRUE)
    aggregation <- "mean_4x15min"
    out_res <- "hour"
  }

  list(
    info = list(
      issue_datetime = as.POSIXct(NA_real_, origin = "1970-01-01", tz = "Europe/Madrid"),
      market_date = dates,
      file_path = file
    ),
    values = list(price_es = es, price_pt = pt),
    raw_resolution = raw_res,
    resolution = out_res,
    n_periods_raw = n_raw,
    n_periods = length(es),
    dst_adjusted = n_raw != pinfo$target,
    dst_type = .omie_dst_type(n_raw, pinfo$target),
    aggregation = aggregation,
    file_type = "marginalpdbc"
  )
}

.omie_parse_file <- function(file, source, resolution, check_header = TRUE) {
  if (source == "results") {
    .omie_parse_results(file, resolution, check_header = check_header)
  } else if (source == "marginalpdbc") {
    .omie_parse_marginalpdbc(file, resolution)
  } else {
    stop("Unsupported source: ", source)
  }
}

.omie_input_files <- function(file = NULL, input_dir = NULL, source = "results") {
  if (!is.null(file) && !is.null(input_dir)) {
    stop("Use only one local input: either 'file' or 'input_dir'.")
  }
  x <- if (!is.null(file)) file else input_dir
  if (is.null(x)) return(character())
  x <- as.character(x)
  dirs <- x[dir.exists(x)]
  direct <- x[!dir.exists(x)]
  from_dirs <- unlist(lapply(dirs, function(d) {
    all <- list.files(d, recursive = TRUE, full.names = TRUE, all.files = FALSE)
    if (source == "results") {
      all[grepl("\\.(txt|TXT)$", all) | grepl("INT_PBC_EV_H", basename(all), fixed = TRUE)]
    } else {
      all[grepl("^marginalpdbc_[0-9]{8}(\\.[0-9]+)?$", basename(all),
                ignore.case = TRUE)]
    }
  }), use.names = FALSE)
  files <- unique(c(direct, from_dirs))
  miss <- files[!file.exists(files)]
  if (length(miss)) stop("File(s) not found: ", paste(miss, collapse = ", "))
  sort(files)
}

.omie_source_vars <- function(source) {
  if (source == "marginalpdbc") c("price_es", "price_pt") else names(.omie_var_dictionary())
}

.omie_argvals <- function(resolution) {
  if (resolution == "hour") seq(0.5, 23.5, by = 1) else (seq_len(96L) - 0.5) / 4
}

.omie_period_labels <- function(resolution) {
  if (resolution == "hour") paste0("H", sprintf("%02d", 1:24)) else
    unlist(lapply(1:24, function(h) paste0("H", h, "Q", 1:4)), use.names = FALSE)
}

.omie_build_fdata <- function(mat, var_name, resolution) {
  argvals <- .omie_argvals(resolution)
  fd <- fda.usc::fdata(
    mat,
    argvals = argvals,
    rangeval = c(0, 24),
    names = list(main = var_name, xlab = "Hours", ylab = unname(.omie_var_units()[var_name]))
  )
  attr(fd, "var_name") <- var_name
  attr(fd, "var_units") <- unname(.omie_var_units()[var_name])
  attr(fd, "resolution") <- resolution
  attr(fd, "source") <- "OMIE"
  fd
}

.omie_fdata_from_df <- function(dat, var_name, resolution) {
  if (!var_name %in% names(dat)) stop("Variable '", var_name, "' not found in data.")
  dates <- sort(unique(as.Date(dat$date)))
  nper <- if (resolution == "hour") 24L else 96L
  mat <- matrix(NA_real_, nrow = length(dates), ncol = nper,
                dimnames = list(as.character(dates), .omie_period_labels(resolution)))
  di <- match(as.Date(dat$date), dates)
  pi <- as.integer(dat$period)
  ok <- !is.na(di) & !is.na(pi) & pi >= 1L & pi <= nper
  mat[cbind(di[ok], pi[ok])] <- as.numeric(dat[[var_name]][ok])
  .omie_build_fdata(mat, var_name, resolution)
}

.omie_save_object <- function(x, output_file, name = "x") {
  if (is.null(output_file)) return(invisible(NULL))
  dir <- dirname(output_file)
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  ext <- tolower(tools::file_ext(output_file))
  if (ext == "rds") {
    saveRDS(x, output_file)
  } else if (ext == "rdata" || ext == "rda") {
    e <- new.env(parent = emptyenv())
    assign(name, x, envir = e)
    save(list = name, envir = e, file = output_file)
  } else {
    stop("Unsupported output extension. Use .rds, .RData or .rda.")
  }
  invisible(NULL)
}
