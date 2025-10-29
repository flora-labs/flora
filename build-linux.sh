#!/bin/bash
# Build Linux binary with Docker

echo "Building Linux binary with chain ID fixes..."

# Use Docker to build for Linux
docker run --rm -v "$PWD":/workspace -w /workspace golang:1.23 sh -c '
    apt-get update && apt-get install -y build-essential
    go mod download
    CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build \
        -tags "netgo" \
        -ldflags="-s -w" \
        -o florad-linux \
        ./cmd/florad
'

if [ -f florad-linux ]; then
    echo "Linux binary built successfully"
    ls -lh florad-linux
    file florad-linux
else
    echo "Build failed"
    exit 1
fi