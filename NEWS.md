# omie2fdata 0.0.2

## New functions

* Added `omie2download()` to download daily files from OMIE's public
  **Acceso a ficheros** repository. The first supported daily-file families use
  the `<file_type>_YYYYMMDD.<version>` convention, including `marginalpdbc`
  and `curva_pbc` for raw download.
* Added `omie2df()` as the common tabular layer between raw acquisition and
  functional-data conversion. It can read previously downloaded files or use
  temporary internal downloads.

## Updated functions

* `omie2txt()` remains the downloader for the consolidated daily OMIE
  market-results TXT files. It now shares validation, retry and overwrite
  controls with the rest of the package.
* `omie2fdata()` can now obtain the same functional variable from the
  consolidated market-results source or from direct `marginalpdbc` files. It
  also accepts a file, several files, a directory, or a `data.frame` returned
  by `omie2df()`.
* `omie2ldata()` now creates genuine `fda.usc::ldata` objects with
  `fda.usc::ldata()` and accepts the same local/downloaded sources as
  `omie2fdata()`.
* The legacy positional arguments of `omie2fdata()` and `omie2ldata()` are
  retained for compatibility with scripts written for the initial version.

## Data normalization and compatibility

* Hourly resolution remains the default. Quarter-hourly resolution is accepted
  only from 2025-10-01 onward.
* Added direct parsing of `marginalpdbc` files, exposing Spanish and Portuguese
  day-ahead prices as `price_es` and `price_pt`.
* Hourly and quarter-hourly functional domains now use interval midpoints:
  0.5, 1.5, ..., 23.5 and 0.125, 0.375, ..., 23.875, respectively.
* Daylight-saving-time normalization records the original number of periods,
  the adjustment type and any aggregation applied.
* Restored support for legacy OMEL/OMIE files with `Precio marginal
  (Cent/kWh)`, converting prices to `EUR/MWh`.
* Legacy `Precio marginal` is recognized as `price_es`; `Demanda+bombeos` is
  exposed separately as `demand_es`.
* Purchase, sale, Iberian-total and interconnection series use MW as the common
  functional unit. Historical hourly MWh values are numerically equivalent to
  average MW over a one-hour interval.

## Documentation, examples and tests

* Added tests for legacy OMEL data, current hourly data, quarter-hourly data,
  `marginalpdbc`, `fdata`, `ldata`, DST handling and legacy positional calls.
* Added bundled raw OMIE examples in `inst/extdata` for reproducible examples
  without network access; their provenance and OMIE attribution are documented
  alongside the files.
* Expanded the vignette to show internal download, reuse of previously
  downloaded files, direct-repository files, and construction of an annual
  price/market-purchase `ldata` object.

# omie2fdata 0.0.1

Initial package version (March 2026), previously distributed with version
number `0.1.0` and recorded here as `0.0.1` to normalize the development
version history.

## Functions

* `omie2txt()` downloaded the consolidated daily OMIE market-results TXT files
  for a date range. Hourly data were the default and 15-minute files could be
  requested from 2025-10-01 onward. Files could be kept in a local directory or
  downloaded to temporary files.
* `omie2fdata()` read previously downloaded TXT files or called `omie2txt()`
  internally and returned one `fdata` object, or a named list of `fdata`
  objects for several variables. The initial default variables were
  `price_es`, `buy_es` and `sell_es`.
* `omie2ldata()` used the same consolidated TXT source to combine several
  aligned daily variables in an `ldata`-like object with shared metadata.

The initial implementation supported the consolidated OMIE results source,
local `input_dir` workflows, optional `.rda` output, hourly and quarter-hourly
resolutions, and the original OMIE variable dictionary used by the package.
