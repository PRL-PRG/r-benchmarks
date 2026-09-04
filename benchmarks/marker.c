/* The clock `harness_instrument.R` stamps its phase markers with.
 *
 * `perf record -k1` timestamps its samples with CLOCK_MONOTONIC
 * so we can distinguish different parts of the find perf recording.
 * For example, we can isolate the `execute()` from the rest.
 *
 * The problem is that R has no monotonic clock of its own.
 * `Sys.time()` is CLOCK_REALTIME hence we need this helper.
 *
 * Compile: R CMD SHLIB marker.c -o marker.so
 */

#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <time.h>

SEXP rbench_monotonic(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return Rf_ScalarReal((double)ts.tv_sec + 1e-9 * (double)ts.tv_nsec);
}
