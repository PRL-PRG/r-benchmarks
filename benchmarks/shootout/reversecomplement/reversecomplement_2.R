# ------------------------------------------------------------------
# The Computer Language Shootout
# http://shootout.alioth.debian.org/
#
# Contributed by Leo Osvald
# ------------------------------------------------------------------
# Output replaced by checksum. The original shootout benchmark writes its
# generated data to stdout, which could mean hundreds of kilobytes per iteration
# resulting in IO dominating the benchmark.
.cksum <- 0
.ck <- function(x) {
    v <- if (is.character(x)) utf8ToInt(paste0(x, collapse = "")) else as.integer(x)
    .cksum <<- (.cksum + sum(v)) %% 2147483647L
}


codes <- c(
    "A", "C", "G", "T", "U", "M", "R", "W", "S", "Y", "K", "V", "H", "D", "B",
    "N")
complements <- c(
    "T", "G", "C", "A", "A", "K", "Y", "W", "S", "R", "M", "B", "D", "H", "V",
    "N")
comp_map <- NULL
comp_map[codes] <- complements
comp_map[tolower(codes)] <- complements

execute <- function(n=150000L) {
    .cksum <<- 0
    in_filename <- paste("../fasta/fasta", n, ".txt", sep="")
    f <- file(in_filename, "r")
    lines <- readLines(f)
    for (i in 1:length(lines)) {
        codes <- strsplit(lines[[i]], split="")[[1]]
        if (codes[[1]] == '>')
            .ck(lines[[i]])
        else {
            .ck(paste(comp_map[codes], collapse=""))
        }
    }
    close(f)
    cat("reversecomplement_2 checksum:", .cksum, "\n")
}
