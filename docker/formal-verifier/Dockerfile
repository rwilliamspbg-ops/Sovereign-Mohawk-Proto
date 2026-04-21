FROM ubuntu:24.04

ARG GO_VERSION=1.25.9

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        python3 \
        python3-venv \
        python3-pip \
        git \
        make \
        bash \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -o /tmp/elan-init.sh \
    && bash /tmp/elan-init.sh -y \
    && rm -f /tmp/elan-init.sh \
    && /root/.elan/bin/elan toolchain install leanprover/lean4:v4.30.0-rc2 \
    && /root/.elan/bin/elan default leanprover/lean4:v4.30.0-rc2

RUN curl -fsSLo /tmp/go.tgz "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
    && rm -rf /usr/local/go \
    && tar -C /usr/local -xzf /tmp/go.tgz \
    && rm -f /tmp/go.tgz

ENV PATH="/usr/local/go/bin:/root/.elan/bin:${PATH}"
WORKDIR /workspace

CMD ["bash", "-lc", "make validate-formal"]
