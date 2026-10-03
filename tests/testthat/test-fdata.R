test_that("omie2fdata returns fdata with common time domain", {
  f <- system.file("extdata", "marginalpdbc_20260727.1", package = "omie2fdata")
  fd <- omie2fdata("2026-07-27", "2026-07-27", var_names = "price_es",
                   resolution = "15min", source = "marginalpdbc", file = f)
  expect_s3_class(fd, "fdata")
  expect_equal(dim(fd$data), c(1L, 96L))
  expect_equal(fd$rangeval, c(0, 24))
  expect_equal(fd$argvals[c(1, 96)], c(0.125, 23.875))
})

test_that("omie2ldata is built with fda.usc ldata", {
  f <- system.file("extdata", "marginalpdbc_20260727.1", package = "omie2fdata")
  ld <- omie2ldata("2026-07-27", "2026-07-27",
                   var_names = c("price_es", "price_pt"),
                   resolution = "15min", source = "marginalpdbc", file = f)
  expect_s3_class(ld, "ldata")
  expect_true(all(c("df", "price_es", "price_pt") %in% names(ld)))
  expect_equal(nrow(ld$df), nrow(ld$price_es$data))
})

test_that("legacy positional fdata arguments remain accepted", {
  f <- system.file("extdata", "omie_2025-04-01.txt", package = "omie2fdata")
  d <- tempfile("omie_local_")
  dir.create(d)
  file.copy(f, file.path(d, basename(f)))
  out <- tempfile("omie_out_")
  fd <- omie2fdata("2025-04-01", "2025-04-01", "price_es", "hour",
                   d, out, FALSE, 123, TRUE)
  expect_s3_class(fd, "fdata")
  expect_true(length(list.files(out, pattern = "price_es_hour_.*\\.rda$")) == 1L)
})
