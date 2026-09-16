# NOTE: `iterations` is accepted but, as in the original benchmark, never used --
# the loop below intentionally uses `iter` (passed separately) to preserve the
# original (already-nested) behavior where both r1 and r2 run for the same
# number of iterations regardless of the `iterations` argument.
EM.censored.poisson <- function(n, m, c, lambda0 = (n * m + c) / (n + c), iterations, iter) {
  log.likelihood <- function(lambda)
  {n * m * log(lambda) - (n + c) * lambda + c * log(1 + lambda)}

  lambda <- lambda0
  old.ll <- log.likelihood(lambda)

  for (i in 1:iter) {
    p1 <- lambda / (1+lambda)
    lambda <- (n*m + c*p1) / (n+c)
    new.ll <- log.likelihood(lambda)

    if (new.ll - old.ll < -1e-6) {stop("Log likelihood decreased!")}
    old.ll <- new.ll
  }
  lambda
}

execute <- function(iter = 10L) {
  for (i in 1:3) r1 <- EM.censored.poisson(5,6.1,20,(iter*1000), iterations=NA, iter=iter)
  for (i in 1:30000) r2 <- EM.censored.poisson(5,6.1,20,iter, iterations=NA, iter=iter)

  res <- list(r1,r2)
  print(res)
  invisible(res)
}
