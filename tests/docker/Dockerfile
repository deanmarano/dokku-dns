# Use minimal Ubuntu base
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install all dependencies in one optimized layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    git \
    sudo \
    wget \
    openssh-client \
    awscli \
    dnsutils \
    netcat-openbsd \
    ca-certificates \
    unzip \
    xz-utils \
    docker.io \
    shellcheck \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Install BATS efficiently
RUN git clone --depth=1 https://github.com/bats-core/bats-core.git /tmp/bats \
    && /tmp/bats/install.sh /usr/local \
    && rm -rf /tmp/bats

# Set up working directory
WORKDIR /plugin

# Copy test scripts and make executable
COPY tests/docker/run-tests.sh /tests/run-tests.sh
COPY tests/docker/dokku-wrapper.sh /usr/local/bin/dokku-wrapper.sh
COPY scripts/test-docker.sh /test-docker.sh
RUN chmod +x /tests/run-tests.sh /test-docker.sh /usr/local/bin/dokku-wrapper.sh

# Create dokku command symlink
RUN ln -sf /usr/local/bin/dokku-wrapper.sh /usr/local/bin/dokku

# Default command
CMD ["/tests/run-tests.sh"]