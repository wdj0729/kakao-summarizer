#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
swift build -c release
mkdir -p "$HOME/.local/bin"
cp .build/release/kakao-read "$HOME/.local/bin/kakao-read"
echo "installed: $HOME/.local/bin/kakao-read"
