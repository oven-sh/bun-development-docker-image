# Bun Debug Docker Image

A daily-built multi-architecture Docker image for **debug builds of Bun** that contains:

1. A base image with a pre-setup Bun development environment
2. A pre-built image with compiled artifacts

Both images are published to GitHub Container Registry daily for both AMD64 and ARM64 architectures.

Note: this is not for developing applications with Bun, but rather for developing Bun itself.

## Usage

### Base Development Image

```bash
docker pull ghcr.io/oven-sh/bun-development-docker-image:latest
```

This image contains:

- Debian bookworm slim as the base OS
- Bun repository cloned to `/workspace/bun`
- Development dependencies installed
- Bootstrap script already executed
- Modern GCC/G++ 12 with full C++20 support (including constexpr std::array<std::string>)

### Pre-built Image

```bash
docker pull ghcr.io/oven-sh/bun-development-docker-image:prebuilt
```

This image includes everything in the base image, plus:

- Pre-compiled build artifacts from running `bun run build`

### Heavy Image

```bash
docker pull ghcr.io/oven-sh/bun-development-docker-image:heavy
```

The "everything" image for automated agent / fuzzer work. On top of `:prebuilt`:

- `gh` CLI
- redis, postgres, mariadb (Bun's test suite needs these)
- `vendor/WebKit` source cloned at the matching commit
- Swift toolchain + Fuzzilli built in `/opt/fuzzilli`
- A second Bun build at `build/debug-fuzz/bun-debug` with `ENABLE_FUZZILLI=ON` and Zig ASAN

### Running the Container

```bash
# Run the base development image
docker run -it --rm ghcr.io/oven-sh/bun-development-docker-image:latest

# Run the pre-built image
docker run -it --rm ghcr.io/oven-sh/bun-development-docker-image:prebuilt
```

### Platform-Specific Images

If you need a specific architecture:

```bash
# AMD64
docker run -it --rm --platform linux/amd64 ghcr.io/oven-sh/bun-development-docker-image:latest

# ARM64
docker run -it --rm --platform linux/arm64 ghcr.io/oven-sh/bun-development-docker-image:latest
```

### Mounting Your Local Files

To work on the Bun codebase with your local editor:

```bash
docker run -it --rm -v $(pwd):/workspace/local ghcr.io/oven-sh/bun-development-docker-image:latest
```

## Tags

- `latest`: Multi-platform base development image
- `prebuilt`: Multi-platform image with pre-built artifacts
- `heavy`: `:prebuilt` + gh CLI, databases, WebKit src, Swift+Fuzzilli, ASAN fuzz build
- `YYYY-MM-DD`: Date-specific base development image
- `prebuilt-YYYY-MM-DD`: Date-specific image with pre-built artifacts
- `heavy-YYYY-MM-DD`: Date-specific heavy image

## Build Artifacts

Every daily build includes compressed build artifacts for both AMD64 and ARM64 architectures, uploaded as GitHub Actions artifacts.

## Building Locally

To build the image locally:

```bash
# Build base image
docker build -t bun-dev:local --target base .

# Build pre-built image
docker build -t bun-dev:prebuilt --target prebuilt .
```

# Build heavy image (needs :prebuilt to exist locally or be pullable)

docker build -f Dockerfile.heavy -t bun-dev:heavy .
