# Hyperlight JS benchmark

A small, reproducible benchmark for Hyperlight running JavaScript in QuickJS.
The upstream source is pinned as a Git submodule; this repository contains only
the benchmark documentation, runner, and a focused patch.

## What it measures

| Execution path | Representative wall time | Memory |
|---|---:|---:|
| Cold initialization | 38–58 ms, approximately 50 ms | 21.9–22.3 MiB RSS for the first VM |
| File snapshot → fresh VM | 22–40 ms, approximately 30 ms | 2.75–3.25 MiB initial RSS after the first call |
| In-memory snapshot → existing VM | approximately 0.08 ms | Reuses the existing VM |

Additional normally initialized VMs amortize shared process and QuickJS
overhead:

| VM | Incremental RSS |
|---|---:|
| First | 21.9–22.3 MiB |
| Second | 13.25–13.5 MiB |
| Third and later | approximately 12 MiB each |

For the file-backed snapshot path, the observed memory accounting was:

- RSS after the first handler: 2.75–3.25 MiB
- PSS after the first handler: 2.2–2.3 MiB
- Additional virtual mappings: approximately 6.9 MiB
- Anonymous RSS: approximately 0.25 MiB
- File-backed RSS: 2.5–2.75 MiB

The low initial RSS is possible because the snapshot is memory-mapped and
faulted lazily. It is not a permanent memory ceiling. RSS grows as a workload
touches or modifies additional pages.

## Reference environment

- Hyperlight JS release build
- KVM under WSL2
- Small JavaScript handler that increments a JSON value
- Rust 1.89 or later
- Linux `/proc` memory accounting

Hyperlight supports **KVM**, **Windows Hypervisor Platform / Hyper-V**, and
**MSHV**. The figures above were measured only on KVM under WSL2.

## Run

The machine must expose `/dev/kvm`.

```bash
git clone --recurse-submodules https://github.com/jsturtevant/hyperlight-js-benchmark.git
cd hyperlight-js-benchmark
./run-benchmark.sh
```

If the repository was cloned without submodules, the runner initializes the
submodule automatically.

The command:

1. Initializes the pinned `hyperlight-js` submodule.
2. Applies `patches/hyperlight-js-benchmark.patch` if it is not already applied.
3. Installs the `x86_64-unknown-none` Rust target if needed.
4. Builds a release binary.
5. Prints cold initialization, sequential VM memory, file snapshot, in-memory
   snapshot, warm execution, and batch-density measurements.

Results vary with CPU frequency, host load, kernel, WSL scheduling, and
hypervisor behavior. Compare release builds on the same machine.

## Handler

```javascript
function handler(event) {
  event.answer = event.value + 1;
  return event;
}
```

Input:

```json
{"value":41}
```

Expected output:

```json
{"value":41,"answer":42}
```

## Snapshot prototype

The patch adds convenience APIs to `LoadedJSSandbox`:

```rust
loaded.save_file_snapshot("./quickjs-snapshot", "initialized")?;

let mut restored = LoadedJSSandbox::from_file_snapshot(
    "./quickjs-snapshot",
    "initialized",
)?;
```

Snapshots use Hyperlight's OCI Image Layout format. The benchmark uses
`Snapshot::load`, without digest verification, to isolate normal load
performance. The convenience restore supports snapshots without custom host
modules; those require the original host-function implementations.

Hyperlight file snapshots are currently tied to the CPU architecture,
hypervisor, and CPU vendor on which they were created. The on-disk format is
not guaranteed to remain compatible across Hyperlight `0.x` releases.

## Repository structure

```text
.
├── patches/hyperlight-js-benchmark.patch
├── upstream/hyperlight-js/             # pinned Git submodule
├── LICENSE
├── README.md
└── run-benchmark.sh
```

## License

Apache-2.0, matching the upstream Hyperlight JS project.
