# Usage

Install the backend as described in [Installation](installation.md) first.

## First computation

```julia
using PerfectForms
result = enumerate_perfect_forms(5)
length(result.data["representatives"])  # 2
result.data["representatives"][1]["gram"]
result.run_directory                  # input, output, logs, process.json
result.process_info["elapsed_seconds"]
backend_build_info()["nauty_library"]
```

## Quadratic orders and classical forms

The discriminant convenience interface describes quadratic orders in any rank:

```julia
result = enumerate_perfect_forms(33)             # real quadratic, rank 2
result = enumerate_perfect_forms(-4)             # Gaussian Hermitian forms
result = enumerate_perfect_forms(1; dimension=4) # classical rational forms
```

Discriminant 1 selects classical forms. Otherwise a nonsquare discriminant
congruent to 0 or 1 modulo 4 selects a real (positive) or imaginary (negative)
quadratic order. Fundamental discriminants select maximal orders; other order
discriminants are accepted too. D8 denotes Q(sqrt(2)), for example. The default
rank is two. Upstream performs its own interpretation and validation.

## Results

The result is a named tuple `(data, raw, run_directory, process_info)`.
`data` is parsed exact JSON: rational numbers, integer matrix entries and group
orders remain strings, preserving arbitrary precision. `raw` is the JSON text.

## Configuration and resources

Configuration selects one absolute executable path and verifies its SHA256:

```julia
config = default_backend(config_path="/absolute/install/config.json")
result = enumerate_perfect_forms(12; config, timeout=180.0,
    work_dir="results/runs", memory_limit=10*1024^3)
```

`BackendConfig("/absolute/path/to/executable")` is also available for an
explicitly selected executable. See [Backend configuration](configuration.md) for selection and troubleshooting.
`backend_build_info(config)` checks the installed `backend-build.json` against
the selected binary. For an uninstalled build, pass its provenance with `path=`.

## General T-spaces

For general inputs, pass upstream option names in named tuples or dictionaries:

```julia
result = enumerate_perfect_forms(; tspace=(TypeTspace="ImagQuad",
    RealImagDim=2, RealImagSum=0, RealImagProd=1, ListComm="Use_realimag"))
result = enumerate_perfect_forms(; tspace=Dict("TypeTspace"=>"Raw",
    "FileListMat"=>abspath("form_basis.txt"), "SuperMatMethod"=>"Compute"))
```

Options in `tspace` and `data` use the upstream `TSPACE` and `DATA` names. There is
no package-specific list of allowed T-space types or options. Use absolute
paths for auxiliary inputs, since the child runs in a private request directory.
For an existing upstream namelist, pass its contents unchanged:

```julia
result = enumerate_perfect_forms(read("input.nml", String))
```

PerfectForms defaults to `ComputeComplex=F` even when a raw namelist omits
that option. The upstream full-complex driver's default is independent.

## Process interface and guarantees

The equivalent low-level process interface is:

```julia
request = perfect_form_request(8)
result = run_exporter(request, config; timeout=60.0)
```

Each request uses private files, a fresh request token and an outer deadline.
The default memory policy is a hard address-space limit on Linux and a sampled
RSS watchdog on macOS. `memory_policy=:resident` selects the watchdog on Linux
too, suitable for ASan's large virtual shadow memory. Sampling may overshoot
the memory budget between measurements. Errors throw `BackendError` with `kind`,
`message` and a diagnostic `run_directory`. No completed output is accepted after
a timeout, changed executable, stale token or incompatible export schema.

The wrapper checks the process/protocol contract, not the mathematical claims
in the export. Its process status is `exported_pending_validation`. Independent
mathematical validation belongs in the caller, such as ArithmeticVoronoi.
The existing `AV_ExportPerfectOrbits` name and `av_*` JSON schemas are retained
for compatibility with saved arithmetic datasets.
