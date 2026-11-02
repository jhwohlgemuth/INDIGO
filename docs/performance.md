# Performance measurements

INDIGO treats build speed, image size, and idle resource use as measurements,
not proxies for energy use. Record the Docker host, exact repository revision,
image identity, and measurement method with every result. Do not compare runs
from different hosts or input revisions as if they were controlled before/after
results.

```pikchr
scale = 0.76
Context: box "Host + revision +" "image identity" wid 1.3in ht 0.52in rad 0.08in fill 0xF3F0FF thickness 0
Build: box "Cold / warm" "build" wid 1.05in ht 0.52in rad 0.08in fill 0xEDE9FE thickness 0 at Context+(1.8in,0.55in)
Idle: box "Settled idle" "samples" wid 1.05in ht 0.52in rad 0.08in fill 0xE0E7FF thickness 0 at Context+(1.8in,-0.55in)
arrow from Context.e right 0.25in then up until even with Build then to Build.w thick color 0x5B4BC4
arrow from Context.e right 0.25in then down until even with Idle then to Idle.w thick color 0x5B4BC4
Evidence: box "Raw evidence" wid 1.05in ht 0.52in rad 0.08in fill 0xF3E8FF thickness 0 at Context+(3.6in,0)
arrow from Build.e right 0.25in then down until even with Evidence then to Evidence.w thick color 0x5B4BC4
arrow from Idle.e right 0.25in then up until even with Evidence then to Evidence.w thick color 0x5B4BC4
arrow right 0.4in from Evidence.e thick color 0x5B4BC4
Compare: box "Controlled" "comparison" wid 1.05in ht 0.52in rad 0.08in fill 0xF5F3FF thickness 0
```

## Reproduce a build measurement

`scripts/benchmark.sh` writes disposable evidence below
`.indigo/benchmarks` by default. That directory is excluded from the Docker
build context and is not committed. The benchmark never downloads a model.

On a clean checkout, capture the host and a cold CPU build:

```shell
scripts/benchmark.sh host
scripts/benchmark.sh build baseline-cold indigo:benchmark-cold \
  --no-cache \
  --build-arg NOTEBOOK_VERSION=1.0.5 \
  --build-arg NOTEBOOK_DIGEST=sha256:c3256bd1d46ffd71f6c7b95cc0da7cca1c2ddc417070f3a7622bd557838be7dd \
  --build-arg INDIGO_LLAMA_BACKEND=cpu \
  --build-arg INDIGO_LLAMA_BUILD_JOBS=2 \
  .
```

Repeat the same command without `--no-cache` and with a distinct label and tag
to capture a warm build. For the service-edit cache test, change only a copied
service script, repeat the warm build, and inspect `build.log` for the inference
compile step. Restore the test edit afterward. A successful isolation result
shows the expensive llama.cpp build layer as cached while the service-copy
layer is rebuilt.

Each build directory contains the exact command, elapsed wall time, status,
image ID, local image size, available digest, BuildKit metadata, host metadata,
and the plain BuildKit log. Wall time and image bytes are directly measured.
They do not by themselves establish lower energy use.

## Reproduce idle measurements

Start the exact stack or preset under test without downloading or loading a
model.

The minimal Compose preset can be rendered and started alongside the CPU and
isolated-storage overrides:

```shell
docker compose -f compose.yaml -f compose.cpu.yaml \
  -f compose.isolated.yaml -f compose.minimal.yaml config --quiet
docker compose -f compose.yaml -f compose.cpu.yaml \
  -f compose.isolated.yaml -f compose.minimal.yaml up -d
```

Minimal mode defaults to an 8,192-token context, a 512-token logical batch, a
256-token physical batch, and one parallel inference slot. Set
`LLAMA_ARG_CTX_SIZE`, `LLAMA_ARG_BATCH`, `LLAMA_ARG_UBATCH`, or
`LLAMA_ARG_N_PARALLEL` before Compose to tune them. Context, batch, and
parallelism affect model-loaded memory and throughput; idle-without-model
measurements do not establish their loaded-model cost.

After its services settle, pass the running container name to the benchmark:

```shell
INDIGO_BENCHMARK_SAMPLES=6 INDIGO_BENCHMARK_INTERVAL=10 \
  scripts/benchmark.sh idle full-stack indigo
```

The benchmark records raw Docker CPU percentage, memory usage and percentage,
network I/O, block I/O, and process count for every sample. It also preserves
the container inspection document so the image and environment can be audited.
The benchmark does not start, stop, or remove containers.

Host power is reported as `unavailable` unless
`INDIGO_POWER_READER=/path/to/executable` names an executable that prints one
numeric watts reading per invocation. Power readings from different scopes
(whole host, package, GPU, or outlet) are not interchangeable; document the
reader and scope beside the result.

## Recorded comparison

The baseline below used commit `c70dba762ef17a93c9da080a4341a6e29a864916`
plus the benchmark script and documentation, before the Dockerfile optimization.
It ran on Docker host `Dante` (Ubuntu 24.04.5 LTS, ARM64, 20 CPUs,
130,594,156,544 bytes RAM, Docker Engine 29.1.3). The CPU image used the pinned
Notebook 1.0.5 digest and two llama.cpp build jobs. No model was downloaded or
loaded. The full-service idle container enabled inference, both MCP services,
OpenViking, and Pinokio; six samples over 57 seconds averaged 5.32% Docker CPU
and 893.4 MiB RAM. Host power was not available. The local image ID was
`sha256:bdc30f3c2727b3aa9360a8264d41e7f964d042b6806ec1df025e4f4bd5f0fda0`.

Preserve raw evidence outside Git or attach it to the release/CI run; record
only the compact, reviewable result in this document.

| Revision and mode | Host | Build time | Image size | Idle CPU/RAM | Power |
| --- | --- | ---: | ---: | --- | --- |
| Baseline cold / warm; full services idle | Dante, ARM64, 20 CPUs | 519s / 5s | 10,164,209,027 bytes | 5.32% / 893.4 MiB | Not available |
| Optimized cold / warm; service-only edit | Dante, ARM64, 20 CPUs | 328s / 7s; edit 6s | 10,164,224,672 bytes | Not measured | Not available |
| Minimal preset idle | Dante, ARM64, 20 CPUs | Not applicable | Same optimized image | 4.49% / 354.4 MiB | Not available |

The minimal preset measurement used the same no-model method and six samples
over 57 seconds. Relative to the full-service baseline it reduced observed idle
Docker CPU by 15.6% and RAM by 60.3%. These are host-specific runtime results,
not energy measurements.
