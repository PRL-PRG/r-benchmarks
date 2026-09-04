sq_dist <- function(M, v) colSums((M-v)^2)

near <- function(M, V, P, t, proj_M=P%*%M) {
  count <- numeric(ncol(V))
  dist <- numeric(ncol(V))

  for (j in 1:ncol(V)) {
    sqd <- sq_dist(proj_M, as.vector(P %*% V[,j]))
    c <- 0
    d <- Inf

    for (i in 1:length(sqd)) {
      if (sqd[i] < t) {
        c <- c + 1
        d2 <- sum((M[,i]-V[,j])^2)
        if (d2 < d) d <- d2
      }
    }

    count[j] <- c
    dist[j] <- sqrt(d)
  }

  list(count=count, dist=dist)
}

# setup() generates the three operands into `.data`; execute() only reads them and
# still computes the projection itself, where upstream had it. The generation is a
# few hundred kB here, far too little to be worth a file (see harness.R), and
# `near_large` prepares its operands the same way, so the pair stays comparable.
.data <- NULL       # filled by setup(); execute() only reads it

setup <- function(size = 20L) {
  set.seed(1)
  p_dim <- max(5, round(size/4))
  P <- matrix(runif(p_dim*size,-2,+2), p_dim, size)
  M <- matrix(rnorm(size*10*size), size, 10*size)
  V <- matrix(rnorm(size*size), size, size)
  .data <<- list(P=P, M=M, V=V)
  invisible()
}

execute <- function(size = 20L) {
  P <- .data$P
  M <- .data$M
  V <- .data$V
  proj_M <- P %*% M

  res <- NULL
  for (i in 1:500) res <- unlist(near(M,V,P,8^2,proj_M))
  print(res)
  invisible(res)
}
