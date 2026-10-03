test_that("legacy cent/kWh price is converted to EUR/MWh", {
  f <- system.file("extdata", "omie_1998-01-01.txt", package = "omie2fdata")
  x <- omie2df("1998-01-01", "1998-01-01", var_names = "price_es",
               resolution = "hour", source = "results", file = f)
  expect_equal(nrow(x), 24L)
  expect_equal(x$price_es[1], 27.08, tolerance = 1e-10)
  expect_equal(unname(attr(x, "units")["price_es"]), "EUR/MWh")
})

test_that("current hourly result files expose normalized MW series", {
  f <- system.file("extdata", "omie_2025-04-01.txt", package = "omie2fdata")
  x <- omie2df("2025-04-01", "2025-04-01",
               var_names = c("price_es", "buy_es", "sell_es"),
               source = "results", file = f)
  expect_equal(nrow(x), 24L)
  expect_equal(x$price_es[1], 90)
  expect_equal(x$buy_es[1], 14867.9)
  expect_equal(unname(attr(x, "units")["buy_es"]), "MW")
})

test_that("quarter-hour result files use midpoint argvals", {
  f <- system.file("extdata", "omie_2025-10-01_15min.txt", package = "omie2fdata")
  x <- omie2df("2025-10-01", "2025-10-01", var_names = "price_es",
               resolution = "15min", source = "results", file = f)
  expect_equal(nrow(x), 96L)
  expect_equal(x$argval[c(1, 96)], c(0.125, 23.875))
})

test_that("marginalpdbc is parsed as the same price variables", {
  f <- system.file("extdata", "marginalpdbc_20260727.1", package = "omie2fdata")
  x <- omie2df("2026-07-27", "2026-07-27",
               var_names = c("price_es", "price_pt"),
               resolution = "15min", source = "marginalpdbc", file = f)
  expect_equal(nrow(x), 96L)
  expect_equal(x$price_es[1], 166.4)
  expect_equal(x$price_pt[1], 166.4)
})

test_that("15 minute requests before transition are rejected", {
  expect_error(
    omie2df("2025-09-30", "2025-09-30", var_names = "price_es",
            resolution = "15min", source = "results", file = tempfile()),
    "only available from 2025-10-01"
  )
})


test_that("DST normalization uses the 02:00-03:00 block", {
  spring <- omie2fdata:::.omie_adjust_periods(1:23, "hour")
  autumn <- omie2fdata:::.omie_adjust_periods(1:25, "hour")
  expect_equal(length(spring), 24L)
  expect_equal(spring[3], 2.5)
  expect_equal(length(autumn), 24L)
  expect_equal(autumn[3], 3.5)
  expect_equal(autumn[4], 5)
})
