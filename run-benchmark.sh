#!/usr/bin/env bash
set -euo pipefail

rustup target add x86_64-unknown-none
cargo run --release -p hyperlight-js --example slide_benchmark
