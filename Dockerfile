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
# no file behind it fails here.
RUN uv run --script rbench.py --list > /dev/null

RUN mkdir -p /out

# Writable by any uid, so `docker run --user "$(id -u):$(id -g)"` works and a
# mounted output directory does not fill up with root-owned files. Two places
# need it: uv insists on a writable cache even when nothing is left to resolve,
# and the five benchmarks that cache their generated input create a `data/`
# directory next to themselves on first run.
RUN chmod -R a+rwX /opt/uv /out && chmod -R a+rwX benchmarks

# `docker run <image> --include '^areWeFast/' --runs 1` is the whole interface:
# ENTRYPOINT rather than CMD so flags can be appended without repeating the
# driver's name. No default `--R`, because /opt/R/bin is on PATH and the driver
# already resolves a bare `R` there -- one fewer thing to keep in step with the
# install prefix.
#
# Anything that is not the driver needs --entrypoint (the CI failure check runs
# `--entrypoint R`), which is the cost of making the common case short.
ENTRYPOINT ["./rbench.py"]
