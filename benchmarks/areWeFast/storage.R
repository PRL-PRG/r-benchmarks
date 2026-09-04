source('random.r')

count <- 0

buildTreeDepth <- function(depth, random) {
    count <<- count + 1
    if (depth == 1) {
        return (c(nextRandom() %% 10 + 1))
    } else {
        array <- vector("list", length = 4)
        for (i in 1:4) {
            array[[i]] <- buildTreeDepth(depth - 1, random)
        }
        return (array)
    }
}

execute <- function(size = 10L) {
    count <<- 0
    resetSeed()
    buildTreeDepth(size, nextRandom())
    cat(size, " ", count, "\n")
    invisible(count)
}

