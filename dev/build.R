# =====================================================================
#  Build and check omie2fdata
#  Run from the package root
# =====================================================================

unlink(c("inst/doc", "doc"), recursive = TRUE)

# 1. Documentation: NAMESPACE + man/
devtools::document()
for (f in list.files("man", "\\.Rd$", full.names = TRUE)) tools::checkRd(f)

# 2. README.md from README.Rmd
devtools::build_readme()

# 3. Check and install
chk <- devtools::check()
# capture.output(print(chk), file = "dev/check.log")
if (length(chk$errors)) stop("R CMD check reported errors; see dev/check.log")
devtools::install()

# 4. Website

pkgdown::clean_site(force = TRUE)
pkgdown::build_site()

# 5. Before a CRAN submission
# devtools::check_win_devel()

# 
# # 1. package documentation
# f <- "R/omie2fdata-package.R"
# x <- readLines(f)
# x <- x[!grepl("@docType.*package", x)]
# x <- sub("^NULL$", "\"_PACKAGE\"", x)
# if (!any(grepl("@keywords internal", x))) {
#   i <- grep("\"_PACKAGE\"", x)[1]
#   x <- append(x, "#' @keywords internal", after = i - 1)
# }
# writeLines(x, f)
# 
# # 2. setNames
# f <- "R/omie2df.R"
# x <- readLines(f)
# x <- gsub("(?<!stats::)setNames\\(", "stats::setNames(", x, perl = TRUE)
# writeLines(x, f)
# 
# # 3. exclude pkgdown from build
# f <- ".Rbuildignore"
# x <- if (file.exists(f)) readLines(f) else character()
# if (!any(grepl("_pkgdown", x))) x <- c(x, "^_pkgdown\\.yml$")
# writeLines(x, f)
# 
# # 4. clean website before rebuilding
# unlink("docs", recursive = TRUE)
# 
# devtools::document()
# 
# grep("@docType|_PACKAGE|keywords", readLines("R/omie2fdata-package.R"), value = TRUE)
# grep("setNames", readLines("R/omie2df.R"), value = TRUE)
# readLines(".Rbuildignore")


# setwd("C:/Users/Manuel Oviedo/github/OMIE/omie2fdata")
# 
# source("dev/download_marginal_examples.R")
# source("dev/compare_sources.R")
