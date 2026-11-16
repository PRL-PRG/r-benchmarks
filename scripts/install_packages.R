installPackages <- function(pkgs, lib, remote = "http://cran.r-project.org", ...) {
  dir.create(lib, recursive = TRUE, showWarnings = FALSE)

  # Get only the missing packages
  installed <- rownames(installed.packages())
  missing <- setdiff(pkgs, installed)

  if (length(missing) == 0L) {
    message("All ", length(pkgs), " packages already installed.")
    return()
  }

  # Install them
  message("Installing ", length(missing), " of ", length(pkgs), " packages:")
  message("  ", paste(missing, collapse = ", "))

  # Setup the remote
  repos <- getOption("repos")
  repos["CRAN"] <- remote

  ncpus <- tryCatch(parallel::detectCores(), error = function(e) 1L)
  install.packages(missing, repos = repos, Ncpus = ncpus, lib = lib, ...)

  # Verify all is installed
  still_missing <- setdiff(pkgs, rownames(installed.packages(lib.loc = lib)))
  if (length(still_missing)) {
    stop("Failed to install ", length(still_missing), " packages: ", paste(still_missing, collapse = ", "))
  }
  message("All ", length(pkgs), " required packages are available.")
}
