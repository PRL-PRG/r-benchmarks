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
