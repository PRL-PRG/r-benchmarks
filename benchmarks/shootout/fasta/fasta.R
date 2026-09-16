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


width <- 60L
myrandom_last <- 42L
myrandom <- function(m) {
    myrandom_last <<- (myrandom_last * 3877L + 29573L) %% 139968L
    return(m * myrandom_last / 139968)
}

alu <- paste(
    "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGG",
    "GAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGA",
    "CCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAAT",
    "ACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCA",
    "GCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGG",
    "AGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCC",
    "AGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA",
    sep="", collapse="")

iub <- matrix(c(
    c(0.27, 'a'),
    c(0.12, 'c'),
    c(0.12, 'g'),
    c(0.27, 't'),
    c(0.02, 'B'),
    c(0.02, 'D'),
    c(0.02, 'H'),
    c(0.02, 'K'),
    c(0.02, 'M'),
    c(0.02, 'N'),
    c(0.02, 'R'),
    c(0.02, 'S'),
    c(0.02, 'V'),
    c(0.02, 'W'),
    c(0.02, 'Y')
), 2)

homosapiens <- matrix(c(
    c(0.3029549426680, 'a'),
    c(0.1979883004921, 'c'),
    c(0.1975473066391, 'g'),
    c(0.3015094502008, 't')
), 2)

repeat_fasta <- function(s, count) {
    chars <- strsplit(s, split="")[[1]]
    len <- nchar(s)
    s2 <- c(chars, chars[1:width])
    pos <- 1L
    while (count) {
        line <- min(width, count)
        next_pos <- pos + line
        .ck(s2[pos:(next_pos - 1)])
        pos <- next_pos
        if (pos > len) pos <- pos - len
        count <- count - line
    }
}

random_fasta <- function(genelist, count) {
    psum <- cumsum(genelist[1,])
    while (count) {
        line <- min(width, count)

        rs <- double(line)
        for (i in 1:line)
            rs[[i]] <- myrandom(1)

        .ck(genelist[2, colSums(outer(psum, rs, "<")) + 1])
        count <- count - line
    }
}

execute <- function(n=1000) {
    .cksum <<- 0
    myrandom_last <<- 42L
    n <- as.integer(n)
    repeat_fasta(alu, 2 * n)
    random_fasta(iub, 3L * n)
    random_fasta(homosapiens, 5L * n)
    cat("fasta checksum:", .cksum, "\n")
}
