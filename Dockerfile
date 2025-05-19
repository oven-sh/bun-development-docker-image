FROM debian:bookworm-slim AS base

# Install dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    unzip \
    build-essential \
    pkg-config \
    libssl-dev \
    python3 \
    wget \
    ca-certificates \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

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

# Bootstrap development environment
RUN sh scripts/bootstrap.sh

# Install modern GCC/G++ with full C++20 support from Debian testing
RUN echo "deb http://deb.debian.org/debian testing main" > /etc/apt/sources.list.d/testing.list && \
    echo "APT::Default-Release \"stable\";" > /etc/apt/apt.conf.d/99defaultrelease && \
    apt-get update && \
    apt-get -t testing install -y gcc-12 g++-12 libstdc++-12-dev && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 120 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-12 120 && \
    update-alternatives --install /usr/bin/cc cc /usr/bin/gcc 120 && \
    update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++ 120 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Verify C++20 support including constexpr std::array<std::string>
RUN echo "#include <array>" > /tmp/test.cpp && \
    echo "#include <string>" >> /tmp/test.cpp && \
    echo "constexpr std::array<std::string, 2> arr{\"test1\", \"test2\"};" >> /tmp/test.cpp && \
    echo "int main() { return 0; }" >> /tmp/test.cpp && \
    g++ -std=c++20 /tmp/test.cpp -o /tmp/test && \
    rm /tmp/test /tmp/test.cpp && \
    g++ --version

ENV PATH="/workspace/bun/build/debug:/workspace/bun/build/release:${PATH}"

# Create a variant with pre-built artifacts
FROM base AS prebuilt

# Build Bun
WORKDIR /workspace/bun

# Have to fit in the github limit.
RUN git pull && bun run build && rm -rf build/debug/CMakeFiles/bun-debug.dir/src

RUN bun-debug --version

CMD ["/bin/bash"]