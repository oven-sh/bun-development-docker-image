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
    perl

# Create workspace directory
RUN mkdir -p /workspace/bun
WORKDIR /workspace

# Install Rust using rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
ENV PATH="/root/.cargo/bin:${PATH}"
RUN rustup default stable && \
    rustup component add rustfmt clippy

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

# Clone Bun repository
RUN git clone https://github.com/oven-sh/bun.git /workspace/bun
WORKDIR /workspace/bun

# Bootstrap development environment and prepare build directories
RUN sh -c "git pull && scripts/bootstrap.sh"



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

# Build only the debug version to save space
RUN bun run build && rm -rf /tmp/*

ENV BUN_DEBUG_QUIET_LOGS=1
ENV BUN_GARBAGE_COLLECTOR_LEVEL=0
ENV BUN_FEATURE_FLAG_INTERNAL_FOR_TESTING=1

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
