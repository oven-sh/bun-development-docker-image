# Bun Development Docker Image

A daily-built multi-architecture Docker image for Bun development that contains:

1. A base image with a pre-setup Bun development environment
2. A pre-built image with compiled artifacts

Both images are published to GitHub Container Registry daily for both AMD64 and ARM64 architectures.

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
- `YYYY-MM-DD`: Date-specific base development image
- `prebuilt-YYYY-MM-DD`: Date-specific image with pre-built artifacts

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
