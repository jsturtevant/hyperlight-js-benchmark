# Hyperlight JS benchmark

A reproducible benchmark for Hyperlight running a small JavaScript handler in
QuickJS. It compares three execution paths:

1. Cold initialization from the guest binary.
2. An initialized QuickJS file snapshot restored into a fresh VM.
3. An in-memory snapshot restored into an already-created VM.

The repository is based on
[`hyperlight-dev/hyperlight-js`](https://github.com/hyperlight-dev/hyperlight-js)
and adds file-snapshot helpers plus the benchmark harness.

## Results observed on the reference machine

These are representative ranges, not universal guarantees.

| Execution path | Wall time to handler result | Memory |
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
**MSHV**. The numbers above were measured only on KVM under WSL2.

## Run the benchmark

The machine must expose `/dev/kvm`.

```bash
./run-benchmark.sh
```

Or run it directly:

```bash
rustup target add x86_64-unknown-none
cargo run --release -p hyperlight-js --example slide_benchmark
```

The default run prints:

- First-VM cold initialization latency, CPU time, and RSS
- Sequential per-VM RSS for four live sandboxes
- File snapshot parse/mmap time
- Fresh VM/vCPU reconstruction time
- File snapshot-to-handler latency and memory accounting
- Warm handler latency
- In-memory snapshot restore latency
- In-memory snapshot-to-handler latency
- Average incremental RSS across twelve live sandboxes

Expect normal variation from CPU frequency, host load, WSL scheduling, kernel,
and hypervisor behavior. Compare release builds on the same machine.

## What is being executed

```javascript
function handler(event) {
  event.answer = event.value + 1;
  return event;
}
```

The event is:

```json
{"value":41}
```

The expected result is:

```json
{"value":41,"answer":42}
```

## Snapshot implementation

The benchmark adds convenience APIs to `LoadedJSSandbox`:

```rust
loaded.save_file_snapshot("./quickjs-snapshot", "initialized")?;

let mut restored = LoadedJSSandbox::from_file_snapshot(
    "./quickjs-snapshot",
    "initialized",
)?;
```

Snapshots use Hyperlight's OCI Image Layout format. The prototype uses
`Snapshot::load`, without digest verification, to isolate normal load
performance. The convenience restore currently supports snapshots without
custom host modules; restoring those requires the original host-function
implementations.

Hyperlight file snapshots are currently tied to the CPU architecture,
hypervisor, and CPU vendor on which they were created. The on-disk format is
also not guaranteed to remain compatible across Hyperlight `0.x` releases.

## License

Apache-2.0, matching the upstream Hyperlight JS project.
