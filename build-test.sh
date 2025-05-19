#!/bin/bash
set -e

OS=linux

case "$(uname -m)" in
  arm64 | aarch64)  ARCH="arm64";;
  x86_64)           ARCH="amd64";;
  *)                ARCH="x64";;
esac

PLATFORM="${OS}/${ARCH}"
echo "Detected platform: $PLATFORM"

echo "Building base development image for $PLATFORM..."
docker build --platform $PLATFORM -t bun-dev:base --target base .

echo "Building pre-built image for $PLATFORM..."
docker build --platform $PLATFORM -t bun-dev:prebuilt --target prebuilt .

echo "Running basic tests..."

echo "Testing base image..."
docker run --platform $PLATFORM --rm bun-dev:base bash -c "bun --version && ls -la /workspace/bun"

echo "Testing pre-built image..."
docker run --platform $PLATFORM --rm bun-dev:prebuilt bash -c "bun --version && ls -la /workspace/bun/build"

echo "Extracting build artifacts..."
CONTAINER_ID=$(docker create --platform $PLATFORM bun-dev:prebuilt)
mkdir -p ./bun-build-artifacts
docker cp $CONTAINER_ID:/workspace/bun/build ./bun-build-artifacts
docker rm $CONTAINER_ID
tar -czvf  ./bun-build-artifacts bun-build-$PLATFORM-$(date +%Y-%m-%d).tar.gz
rm -rf ./bun-build-artifacts

echo "All tests passed!"
echo "Build artifacts saved to: bun-build-$PLATFORM-$(date +%Y-%m-%d).tar.gz"