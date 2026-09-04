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
# still computes the projection itself, where upstream had it. M alone is
# size*20*size normals -- a tenth of what this benchmark measured was the random
# number generator, not the nearest-neighbour search. They are not cached on disk:
# the file is 165 MB at this size and reads back no faster than the draws (see
# harness.R).
.data <- NULL       # filled by setup(); execute() only reads it

setup <- function(size = 1000L) {
  set.seed(2)
  p_dim <- max(100, round(size/10))
  P <- matrix(runif(p_dim*size,-2,+2), p_dim, size)
  M <- matrix(rnorm(size*20*size), size, 20*size)
  V <- matrix(rnorm(size*5*p_dim), size, 5*p_dim)
  .data <<- list(P=P, M=M, V=V)
  invisible()
}

execute <- function(size = 1000L) {
  P <- .data$P
  M <- .data$M
  V <- .data$V
  proj_M <- P %*% M

  res <- near(M,V,P,425^2,proj_M)
  ret <- list(c(mean(res$count),mean(res$count==0)), res$dist[c(1,500)])
  print(ret)
  invisible(ret)
}
