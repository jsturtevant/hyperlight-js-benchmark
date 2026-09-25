#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
submodule="$repo_root/upstream/hyperlight-js"
patch_file="$repo_root/patches/hyperlight-js-benchmark.patch"

git -C "$repo_root" submodule update --init --recursive

if git -C "$submodule" apply --reverse --check "$patch_file" >/dev/null 2>&1; then
    echo "Benchmark patch already applied."
elif git -C "$submodule" apply --check "$patch_file"; then
    git -C "$submodule" apply "$patch_file"
    echo "Applied benchmark patch."
else
    echo "The benchmark patch does not apply cleanly to the pinned submodule." >&2
    exit 1
fi

rustup target add x86_64-unknown-none

cd "$submodule"
cargo run --release -p hyperlight-js --example slide_benchmark
