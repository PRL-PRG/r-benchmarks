FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

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
      locales

# Locale
RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8

ARG R_VERSION=4.5.2
RUN set -eux \
  && cd /tmp \
  && curl -fsSLO "https://cran.r-project.org/src/base/R-${R_VERSION%%.*}/R-${R_VERSION}.tar.gz" \
  && tar -xzf "R-${R_VERSION}.tar.gz" \
  && cd "R-${R_VERSION}" \
  && CFLAGS="-g -O2" CXXFLAGS="-g -O2" FFLAGS="-g -O2" FCFLAGS="-g -O2" \
     ./configure --prefix=/opt/R --without-recommended-packages --with-x=no \
  && make -j"$(nproc)" \
  && make install

ENV PATH=/opt/R/bin:$PATH
ENV RBENCH_RHOME=/opt/R/lib/R

ARG CRAN_SNAPSHOT=https://packagemanager.posit.co/cran/2026-09-01
ENV CRAN_SNAPSHOT=$CRAN_SNAPSHOT

COPY . /r-benchmarks
WORKDIR /r-benchmarks

# Install uv and rbench dependencies
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
RUN /root/.local/bin/uv sync
ENV PATH=/root/.local/bin:$PATH

# Install rbench packages
RUN .venv/bin/python3 <<EOF
import rbench as rb
from pathlib import Path
import sys
e = rb.install_packages(
  ["Matrix", "MASS", "clusterGeneration"],
  Rpath = Path("/opt/R/bin/R"),
  lib = Path("$RBENCH_RHOME/library"),
  remote = Path("$CRAN_SNAPSHOT"),
)
if e.returncode != 0:
  print("Failed to install packages:\n" + e.stderr, file=sys.stderr)
  sys.exit(e.returncode)
EOF

# Make sure rbench runs
RUN ./rbench.py --list > /dev/null

# Writable by any uid. The five benchmarks that cache their generated input
# create a `data/` directory on first run.
RUN chmod -R a+rwX benchmarks

# Clean
RUN apt-get clean
RUN rm -rf /var/cache/apt/lists/* /tmp/* /var/tmp/*

# Defaults
RUN mkdir -p /out
RUN printf "#!/bin/sh\nexec /r-benchmarks/rbench.py --remote $CRAN_SNAPSHOT --library $RBENCH_RHOME"' "$@"\n' > /r-benchmarks/rbench
RUN chmod +x /r-benchmarks/rbench

ENTRYPOINT ["/r-benchmarks/rbench"]
