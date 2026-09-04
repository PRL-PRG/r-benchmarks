# Packages the benchmarks under this directory need, installed into the library
# given as the first argument. Mirrors cran/install_cran.R and
# notebooks/install_packages.R: one library per interpreter, because compiled
# code is not portable across R builds.
#
# Only three, and each is checked by a doctor() in the benchmark that needs it:
#
#   Matrix              8 benchmarks: mathkernel/MMM-T*, R-benchmark-25 att1_5,
#                       att2_4, att2_5, riposte/smv_builtin, RealThing/flexclust
#   MASS                riposte/kmeans, lr, lr_test, pca, pca-blocked
#   clusterGeneration   riposte/lr, lr_test, pca, pca-blocked
#
# Matrix and MASS are *recommended* packages, so they are already present in an R
# built the ordinary way and absent from one built --without-recommended-packages
# (which is how gnur-bc-timing is built). Installing them here rather than
# rebuilding keeps the instrumented interpreter's build flags untouched.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L) stop("usage: install_packages.R <library>")
lib <- args[[1L]]
dir.create(lib, recursive = TRUE, showWarnings = FALSE)

PKGS <- c("Matrix", "MASS", "clusterGeneration")

repos <- getOption("repos")
if (is.null(repos) || !nzchar(repos[["CRAN"]]) || repos[["CRAN"]] == "@CRAN@") {
  repos <- c(CRAN = "https://cloud.r-project.org")
}

# `lib` first on the path so an already-installed copy there counts as present,
# but the interpreter's own library counts too: reinstalling a recommended
# package a normal build already ships would be wasted compilation.
missing <- PKGS[!vapply(PKGS, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing) == 0L) {
  cat("all benchmark packages already available\n")
} else {
  cat("installing:", paste(missing, collapse = ", "), "\n")
  install.packages(missing, lib = lib, repos = repos)

  still <- missing[!vapply(
    missing,
    \(p) requireNamespace(p, quietly = TRUE, lib.loc = c(lib, .libPaths())),
    logical(1)
  )]
  if (length(still)) {
    stop("failed to install: ", paste(still, collapse = ", "))
  }
}
