# The image CI measures in: a from-source vanilla R plus the corpus and its
# dependencies, and nothing else.
#
# Built on GitHub-hosted runners and pushed to ghcr.io; the benchmarks then run
# from it on a self-hosted runner. Splitting it that way keeps the expensive,
# machine-independent half (compiling R, resolving CRAN) on disposable cloud
# workers, and leaves the self-hosted machine doing only the part that actually
# has to happen on known hardware.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Pinned, and inherited by the benchmark children: `bench_env()` passes LANG,
# LC_ALL and LC_COLLATE through to every R process. shootout/knucleotide* sort
# strings and regexdna uses gsub(perl=TRUE), so collation decides their output.
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

# Enough to build R and nothing more. No X11, cairo, png, freetype or fontconfig:
# no benchmark in the corpus opens a graphics device (RealThing/volcano uses the
# `volcano` matrix from `datasets` as elevation data, not as a plot).
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      curl \
      gfortran \
      git \
      libbz2-dev \
      libcurl4-openssl-dev \
      libicu-dev \
      liblzma-dev \
      libpcre2-dev \
      libreadline-dev \
      libssl-dev \
      tzdata \
      xz-utils \
      zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Same shape as the vanilla arm this corpus is normally measured on: -g -O2 for
# every language and --without-recommended-packages, which is what the consuming
# study's tools/build-gnur.sh uses by default. install_packages.R below is what
# puts Matrix and MASS back, so dropping the recommended set costs nothing and
# keeps the package versions decided in one place.
#
# Deliberately no libopenblas-dev, so R links its own reference BLAS. That is
# hermetic and free of threading variance, which is what a correctness gate
# wants; it also means timings here are not comparable to an OpenBLAS build.
ARG R_VERSION=4.5.2
RUN set -eux \
  && cd /tmp \
  && curl -fsSLO "https://cran.r-project.org/src/base/R-${R_VERSION%%.*}/R-${R_VERSION}.tar.gz" \
  && tar -xzf "R-${R_VERSION}.tar.gz" \
  && cd "R-${R_VERSION}" \
  && CFLAGS="-g -O2" CXXFLAGS="-g -O2" FFLAGS="-g -O2" FCFLAGS="-g -O2" \
     ./configure --prefix=/opt/R --without-recommended-packages --with-x=no \
  && make -j"$(nproc)" \
  && make install \
  && cd / \
  && rm -rf "/tmp/R-${R_VERSION}" "/tmp/R-${R_VERSION}.tar.gz"
ENV PATH=/opt/R/bin:$PATH

# A dated snapshot rather than a rolling mirror, so rebuilding this image a month
# from now installs the same three packages. It goes in Rprofile.site because
# install_packages.R reads getOption("repos") and takes only the library as an
# argument. Benchmarks run under --vanilla, which skips the site profile, so this
# cannot reach anything that gets measured.
ARG CRAN_SNAPSHOT=https://packagemanager.posit.co/cran/2026-09-01
RUN printf 'options(repos = c(CRAN = "%s"))\n' "$CRAN_SNAPSHOT" \
      >> "$(R RHOME)/etc/Rprofile.site"

COPY . /r-benchmarks
WORKDIR /r-benchmarks

# Into R's *own* library, which is the only one the sealed run environment can
# see: bench_env() blanks R_LIBS, R_LIBS_USER and R_LIBS_SITE to " ", so a
# site-library install would be invisible to every benchmark. Blanking them here
# too makes the build fail loudly if that ever stops being true.
RUN cd benchmarks \
  && R_LIBS=" " R_LIBS_USER=" " R_LIBS_SITE=" " \
     R --slave --no-restore -f install_packages.R --args "$(R RHOME)/library"

# The drivers are PEP 723 scripts, so `bench` is resolved from git at the rev
# their headers pin. Resolving it in a build layer means the measured run does no
# dependency work and needs no network.
COPY --from=ghcr.io/astral-sh/uv:0.12.7 /uv /usr/local/bin/uv
ENV UV_CACHE_DIR=/opt/uv/cache
ENV UV_PYTHON_INSTALL_DIR=/opt/uv/python

# Doubles as a build-time assertion that the corpus resolves: --list walks every
# suite and prints the tree without running a benchmark, so a SUITES entry with
# no file behind it fails here rather than 20 minutes into a CI run.
RUN uv run --script rbench.py --list > /dev/null

RUN mkdir -p /out
