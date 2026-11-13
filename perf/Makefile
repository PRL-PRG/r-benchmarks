# `harness_instrument.R` needs a monotonic clock and R has none: `Sys.time()` is
# CLOCK_REALTIME, while `perf record -k1` stamps its samples with
# CLOCK_MONOTONIC. marker.so is the two-line shim that closes that gap, and
# without it a profiled run (`rbench_perf.py`) stops at startup.
#
# Build it with the same R you are about to profile, or with any R at all: it
# links against no libR, so one object serves every interpreter in a comparison.
R ?= R

.PHONY: marker clean

marker: marker.so

marker.so: marker.c
	$(R) CMD SHLIB marker.c -o marker.so

clean:
	rm -f marker.o marker.so
