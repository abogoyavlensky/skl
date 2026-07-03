#!/usr/bin/env bash

VERSION=0.1.0
OS=$(uname -s | tr '[:upper:]' '[:lower:]')   # linux | darwin
ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
curl -sSL -o skl.tar.gz \
  "https://github.com/abogoyavlensky/skl/releases/download/v${VERSION}/skl_${VERSION}_${OS}_${ARCH}.tar.gz"
tar -xzf skl.tar.gz
mv skl ~/.local/bin/
