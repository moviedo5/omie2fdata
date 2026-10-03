
<!-- README.md is generated from README.Rmd. -->

# omie2fdata: Functional Data from OMIE

**omie2fdata** downloads and reads public electricity-market data from
[OMIE](https://www.omie.es/) and converts daily trajectories into
`fdata` and `ldata` objects from **fda.usc**.

The package separates acquisition, tabular parsing and functional
conversion:

| Function          | Purpose                                                 |
|-------------------|---------------------------------------------------------|
| `omie2txt()`      | Download consolidated daily market-results TXT files    |
| `omie2download()` | Download daily files from OMIE’s public file repository |
| `omie2df()`       | Parse either source into one common `data.frame`        |
| `omie2fdata()`    | Convert one or more variables to `fdata`                |
| `omie2ldata()`    | Build an `fda.usc::ldata` object                        |

## Sources

`source = "results"` is the default and preserves the original package
workflow based on the daily consolidated OMIE/OMEL market-results files.
These files contain prices and several aggregated market buy, sell and
interconnection series. Stable variable names used by the package
include

``` r
price_es
price_pt
buy_es
sell_es
buy_pt
sell_pt
```

`source = "marginalpdbc"` uses the direct files from OMIE’s **Acceso a
ficheros** repository. These files contain Spanish and Portuguese
day-ahead prices and are normalized to the same `price_es` / `price_pt`
representation.

Hourly resolution is the default. Quarter-hourly resolution is accepted
from **2025-10-01** onward.

## Download the same days from both OMIE sources

The two acquisition routes can be compared using exactly the same market
days.

For a short hourly example around the 28 April 2025 blackout:

``` r
omie2txt(
  start_date = "2025-04-26",
  end_date = "2025-04-30",
  resolution = "hour",
  output_dir = "data/results_apr2025"
)

omie2download(
  file_type = "marginalpdbc",
  start_date = "2025-04-26",
  end_date = "2025-04-30",
  output_dir = "data/marginalpdbc_apr2025"
)
```

For the transition to quarter-hourly data, the equivalent example is 1–3
October 2025:

``` r
omie2txt(
  start_date = "2025-10-01",
  end_date = "2025-10-03",
  resolution = "15min",
  output_dir = "data/results_15min"
)

omie2download(
  file_type = "marginalpdbc",
  start_date = "2025-10-01",
  end_date = "2025-10-03",
  output_dir = "data/marginalpdbc_15min"
)
```

If `output_dir = NULL`, temporary files are used and the data can be
converted directly.

For these two validation windows, `price_es` obtained from the
consolidated results files and from `marginalpdbc` was identical point
by point (`max_abs_diff = 0`).

Real `marginalpdbc` files are therefore not bundled with version 0.0.2.
They can be downloaded directly whenever that acquisition route is
required.

## Bundled April 2025 example

The package includes the **30 original hourly market-results TXT files
for April 2025** in `inst/extdata/results_apr2025`.

This month is small enough for an offline reproducible example and
includes the 28 April 2025 blackout.

``` r
library(omie2fdata)

apr_dir <- system.file(
  "extdata", "results_apr2025",
  package = "omie2fdata"
)

omie_apr2025 <- omie2ldata(
  start_date = "2025-04-01",
  end_date = "2025-04-30",
  var_names = c("price_es", "buy_es"),
  resolution = "hour",
  source = "results",
  file = apr_dir
)

plot(omie_apr2025$price_es)
plot(omie_apr2025$buy_es)
```

The resulting `ldata` object contains two aligned functional components:

- `price_es`: 30 daily price curves with 24 points per day.
- `buy_es`: 30 daily total-buy curves with 24 points per day.

The shared daily information is stored in

``` r
omie_apr2025$df
```

and can be augmented for a particular analysis, for example:

``` r
omie_apr2025$df$weekday <- weekdays(omie_apr2025$df$date)

omie_apr2025$df$weekend <-
  as.POSIXlt(omie_apr2025$df$date)$wday %in% c(0, 6)

omie_apr2025$df$blackout <-
  omie_apr2025$df$date == as.Date("2025-04-28")
```

`buy_es` represents OMIE’s total buy series for the Spanish market. The
variable is deliberately not named `demand_es`, because market purchases
and physical system demand are not the same quantity.

The original hourly files report this magnitude as energy in MWh. From
the quarter-hour format introduced on 1 October 2025, the corresponding
total is reported as power in MW. The package uses MW as the common
functional unit, while keeping the stable variable name `buy_es`.

## Bundled quarter-hour examples

The package also includes the original consolidated files for 1–3
October 2025 in `inst/extdata/results_15min`.

``` r
q_dir <- system.file(
  "extdata", "results_15min",
  package = "omie2fdata"
)

fd_q <- omie2fdata(
  start_date = "2025-10-01",
  end_date = "2025-10-03",
  var_names = "price_es",
  resolution = "15min",
  source = "results",
  file = q_dir
)

plot(fd_q)
```

These curves contain 96 points per day.

Several variables can also be combined in an `ldata` object:

``` r
ld_q <- omie2ldata(
  start_date = "2025-10-01",
  end_date = "2025-10-03",
  var_names = c("price_es", "buy_es"),
  resolution = "15min",
  source = "results",
  file = q_dir
)

plot(ld_q$price_es)
plot(ld_q$buy_es)
```

## Direct `marginalpdbc` source

The same type of price object can be constructed directly from OMIE’s
public file repository without storing the files permanently:

``` r
fd_marginal <- omie2fdata(
  start_date = "2025-10-01",
  end_date = "2025-10-03",
  var_names = "price_es",
  resolution = "15min",
  source = "marginalpdbc"
)

plot(fd_marginal)
```

For Spanish and Portuguese prices together:

``` r
ld_marginal <- omie2ldata(
  start_date = "2025-10-01",
  end_date = "2025-10-03",
  var_names = c("price_es", "price_pt"),
  resolution = "15min",
  source = "marginalpdbc"
)

plot(ld_marginal$price_es)
plot(ld_marginal$price_pt)
```

These examples require an Internet connection.

For development and validation, the scripts

``` text
dev/download_marginal_examples.R
dev/compare_sources.R
```

download the same April and October dates and compare `price_es` between
the two OMIE sources.

## Local files

Previously downloaded files can be read without contacting OMIE. `file`
may be one file, several files, or a directory.

The original `input_dir` argument is retained for compatibility.

For example:

``` r
fd_local <- omie2fdata(
  start_date = "2025-10-01",
  end_date = "2025-10-03",
  var_names = "price_es",
  resolution = "15min",
  source = "results",
  file = q_dir
)

plot(fd_local)
```

## A full year without bundling a derived dataset

The package does not distribute an `omie2025` object.

A complete year can instead be generated locally from the original
hourly market-results files:

``` r
raw_2025 <- "data/omie_2025_hour"

omie2txt(
  start_date = "2025-01-01",
  end_date = "2025-12-31",
  resolution = "hour",
  output_dir = raw_2025
)

omie2025 <- omie2ldata(
  start_date = "2025-01-01",
  end_date = "2025-12-31",
  var_names = c("price_es", "buy_es"),
  resolution = "hour",
  source = "results",
  file = raw_2025
)
```

This produces 365 daily price and market-buy curves locally while
keeping the package itself small.

The representation is related to the daily OMIE energy-market profiles
used in Febrero-Bande, González-Manteiga and Oviedo de la Fuente (2019),
*Computational Statistics*, 34, 469–487,
<doi:10.1007/s00180-018-0844-5>.

## Historical compatibility

The parser recognizes older `Precio marginal` files used by OMEL/OMIE.

Historical prices reported in `cent/kWh` are converted to `EUR/MWh`.

The historical variable `Demanda+bombeos` is exposed separately as
`demand_es` and is not silently mixed with `buy_es`.

For market buy, sell, Iberian-total and interconnection series, the
package uses MW as the common functional unit. Historical hourly values
reported as MWh are numerically equivalent to average MW over a one-hour
interval.

## Time grid and daylight saving time

Hourly curves use interval-midpoint `argvals`

``` text
0.5, 1.5, ..., 23.5
```

and quarter-hourly curves use

``` text
0.125, 0.375, ..., 23.875
```

The functional domain is `[0, 24]` hours.

Days with 23 or 25 hourly periods, or 92 or 100 quarter-hourly periods,
are normalized to a common 24- or 96-point grid.

The original number of periods and information about the
daylight-saving-time adjustment are retained in the daily metadata.

## OMIE data source and citation

The raw examples included in `inst/extdata` retain the original
OMIE/OMEL data content and are used for offline examples and tests.

Their provenance is documented in `inst/extdata/README.md`.

A suitable source citation is:

> OMI-Polo Español, S.A. (OMIE). *OMIE electricity-market public data*,
> market-results or file-access dataset, <https://www.omie.es/>,
> accessed \[date\].

The GPL-2 license applies to the R package code and does not replace the
terms applicable to the underlying OMIE/OMEL source data.
