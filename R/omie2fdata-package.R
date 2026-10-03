#' omie2fdata: OMIE electricity-market data as functional data
#'
#' Tools to download, read and normalize public OMIE electricity-market files
#' and convert daily trajectories into `fdata` and `ldata` objects from
#' the `fda.usc` package.
#'
#' The package separates raw acquisition from conversion:
#' * [omie2txt()] downloads the consolidated daily market-results table.
#' * [omie2download()] downloads daily files from OMIE's public file repository.
#' * [omie2df()] provides a common tabular layer.
#' * [omie2fdata()] and [omie2ldata()] create functional-data objects.
#'
#' @name omie2fdata-package
#' @aliases omie2fdata-package
#' @keywords internal
"_PACKAGE"
