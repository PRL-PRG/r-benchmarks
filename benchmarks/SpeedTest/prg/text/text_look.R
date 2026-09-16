count <- function(s1, s2) {
  cnt <- 0
  for (i in seq_len(min(nchar(s1),nchar(s2))))
    if (substr(s1,i,i) == substr(s2,i,i))
      cnt <- cnt + 1
  cnt
}

execute <- function(size = 50000L) {
  a <- "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  b <- "ABCDEFG.IJKLMNOPQ.STUVWXYZ"
  c <- "........IJ........S....................................................."

  for (i in 1:50000) r1 <- count(a,b)
  for (i in 1:50000) r2 <- count(a,c)

  res <- list(r1,r2)
  print(res)
  invisible(res)
}
