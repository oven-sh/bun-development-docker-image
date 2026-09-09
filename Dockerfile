FROM debian:trixie-slim AS base

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    unzip \
    build-essential \
    pkg-config \
    libssl-dev \
    python3 \
    python3-pip \
    wget \
    ca-certificates \
    gnupg \
    apt-transport-https \
    gcc-12 g++-12 libstdc++-12-dev \
    lsb-release \
    sudo \
    make \
    libtool \
    ruby \
    perl \
    gdb \
    jq \
    ccache \
    ripgrep

# Create workspace directory
RUN mkdir -p /workspace/bun
WORKDIR /workspace

# Install rustup only — no toolchain yet. Bun's build requires a pinned
# nightly (for -Zbuild-std, sanitizers, and unstable APIs used by the Rust
# port); the exact channel + components + cross-targets are declared in the
# repo's rust-toolchain.toml. We install that after the clone so the image
# carries exactly one toolchain that matches the checked-out ref, instead of
# a stale `stable` that the build can't use.
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    --default-toolchain none --profile minimal --no-modify-path
ENV PATH="/root/.cargo/bin:${PATH}"

# Install Bun
RUN case "$(uname -s)" in \
      Linux*)  os=linux;; \
      Darwin*) os=darwin;; \
      *)       os=windows;; \
    esac \
    && case "$(uname -m)" in \
      arm64 | aarch64)  arch=aarch64;; \
      *)                arch=x64;; \
    esac \
    && target="bun-${os}-${arch}" \
    && curl -LO "https://pub-5e11e972747a44bf9aaf9394f185a982.r2.dev/releases/latest/${target}.zip" --retry 5 \
    && unzip ${target}.zip \
    && mkdir -p /usr/local/bun/bin \
    && mv ${target}/bun* /usr/local/bun/bin/ \
    && chmod +x /usr/local/bun/bin/* \
    && ln -fs /usr/local/bun/bin/bun /usr/local/bun/bin/bunx \
    && ln -fs /usr/local/bun/bin/bun /usr/local/bin/bun \
    && ln -fs /usr/local/bun/bin/bunx /usr/local/bin/bunx \
    && rm -rf ${target}.zip ${target}

# Clone Bun repository. BUN_REF lets you build the image against a specific
# branch or tag — e.g. `--build-arg BUN_REF=claude/phase-a-port` for the
# Rust-port branch. Default is main so the daily build is unchanged.
ARG BUN_REF=main
RUN git clone --branch ${BUN_REF} https://github.com/oven-sh/bun.git /workspace/bun
WORKDIR /workspace/bun

ENV BUN_NO_CORE_DUMP=1

# Bootstrap development environment and prepare build directories.
#
# bootstrap.sh pulls LLVM from apt.llvm.org, which intermittently rejects
# requests from CI runners; llvm.sh then reports either "GPG key not
# reachable" or the misleading "Distribution 'debian' ... is not supported"
# (its HEAD probe of apt.llvm.org/<codename>/ failed). bootstrap.sh is
# idempotent, so retry it a few times with a pause instead of failing the
# whole multi-hour pipeline on one flaky request.
RUN git pull && \
    for attempt in 1 2 3 4; do \
        scripts/bootstrap.sh && break; \
        if [ "$attempt" -eq 4 ]; then echo "bootstrap.sh failed after $attempt attempts" >&2; exit 1; fi; \
        echo "bootstrap.sh failed (attempt $attempt), retrying in 60s..." >&2; \
        sleep 60; \
    done

# Install the Rust toolchain the checked-out ref actually wants.
#
# rust-toolchain.toml at the repo root pins an exact nightly channel and
# lists every `components` / `targets` entry the build needs (main pins one
# nightly, the Rust-port branch pins a newer one). rustup reads it and
# installs everything into this layer so the first `cargo build` in a
# container doesn't stall on a multi-hundred-MB download.
# `rustup toolchain install` (bare, rustup ≥ 1.28) does the read;
# the follow-up `cargo --version` is the auto-install path for older rustup
# and doubles as a sanity check. The resolved toolchain is then also set as
# the global default so cargo works outside /workspace/bun too.
#
# On refs without rust-toolchain.toml we fall back to generic `nightly`
# (matching .buildkite/Dockerfile) so there's still a working compiler.
#
# rust-src is required (for -Zbuild-std on Tier-3 targets). rustfmt / clippy
# are dev niceties and occasionally missing from a given nightly, so they're
# best-effort.
RUN set -eux; \
    if [ -f rust-toolchain.toml ]; then \
        rustup toolchain install 2>/dev/null || true; \
        cargo --version; \
        rustup default "$(rustup show active-toolchain | awk '{print $1}')"; \
    else \
        rustup toolchain install nightly --profile minimal; \
        rustup default nightly; \
    fi; \
    rustup component add rust-src; \
    rustup component add rustfmt clippy || echo "rustfmt/clippy unavailable on this nightly; skipping"; \
    rustc --version; \
    rustup show



# Verify C++20 support including constexpr std::array<std::string>
RUN echo "#include <array>" > /tmp/test.cpp && \
    echo "#include <string>" >> /tmp/test.cpp && \
    echo "constexpr std::array<std::string, 2> arr{\"test1\", \"test2\"};" >> /tmp/test.cpp && \
    echo "int main() { return 0; }" >> /tmp/test.cpp && \
    g++ -std=c++20 /tmp/test.cpp -o /tmp/test && \
    rm /tmp/test /tmp/test.cpp && \
    g++ --version

ENV PATH="/workspace/bun/build/debug:/workspace/bun/build/release:${PATH}"


# Create a variant with pre-built artifacts - Only binary
FROM base AS prebuilt

# Build Bun - minimal approach to save space
WORKDIR /workspace/bun

# Clean up and prepare build environment
RUN git pull && \
    # Clean temporary files
    rm -rf /tmp/* && \
    # Remove unnecessary packages
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    # Set up build environment variables
    mkdir -p build/debug && \
    mkdir -p build/debug/cache

ENV ENABLE_ZIG_ASAN=0
ENV BUN_DEBUG_QUIET_LOGS=1
ENV BUN_GARBAGE_COLLECTOR_LEVEL=0
ENV BUN_FEATURE_FLAG_INTERNAL_FOR_TESTING=1

# Build only the debug version to save space
RUN bun run build && rm -rf /tmp/*

# Test that the binary works
RUN bun-debug --version

CMD ["/bin/bash"]

# Minimal stage for extracting build artifacts
FROM scratch AS artifacts
COPY --from=prebuilt /workspace/bun/build /build

FROM prebuilt as run

RUN mkdir -p /workspace/cwd
VOLUME /workspace/cwd
WORKDIR /workspace/cwd

ENTRYPOINT ["/workspace/bun/build/debug/bun-debug"]
