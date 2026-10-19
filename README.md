# PerfectForms.jl

Enumerate perfect-form orbits from Julia using Mathieu Dutour Sikirić's
[polyhedral_common](https://github.com/MathieuDutSik/polyhedral_common) C++ code.

Export exact forms, minimal vectors, stabilizers, facet orbits and labelled
neighbours through a separate executable. This package needs neither Oscar
nor GAP.

The exporter accepts upstream T-space descriptions, including classical
forms, real and imaginary quadratic forms, group-invariant spaces and
spaces supplied by matrix files. Fields and dimensions are not restricted
to a list of tested examples. The compiled arithmetic path is exact GMP
integers/rationals; requests for other arithmetic paths are reported explicitly.
[ArithmeticVoronoi](https://github.com/dimpase/arithmetic_voronoi) provides
independent exact validation of these exports, two-cells, GL/SL/PSL
presentations and constructive matrix-to-word algorithms.

## Install and build

Requirements: Julia 1.10 or newer, Git, CMake 3.24+, Ninja, `pkg-config`,
a C++20 compiler and standard library with `std::format`, and development
headers/libraries for GMP, Eigen 3, Boost.Serialization and nauty/Traces.
Python 3.8+ is used only for tests. Linux runtime memory limits use `prlimit`
from util-linux; macOS uses the system `ps` command.

```bash
git clone https://github.com/dimpase/PerfectForms.jl.git
cd PerfectForms.jl
julia --startup-file=no --project=. -e 'using Pkg; Pkg.instantiate()'
cmake --preset release
cmake --build --preset release
ctest --preset release
cmake --install build
```

The release preset builds serially with `-O1` and installs in `backend/`.
On Linux, prefix the build command with `prlimit --as=10737418240` to impose
a 10 GiB compiler address-space limit. No administrator access is required
after system dependencies are installed. Loading Julia code does not run CMake.

On macOS install current Xcode Command Line Tools and, with Homebrew:

```bash
brew install cmake ninja pkgconf gmp eigen@3 boost nauty
cmake --preset release \
  -DCMAKE_PREFIX_PATH="$(brew --prefix eigen@3);$(brew --prefix)"
```

Then continue with the build, test and install commands above. Detection is
generic: `pkg-config` metadata, `CMAKE_PREFIX_PATH` and ordinary header/library
searches. An installed nauty is required. If necessary specify
`Nauty_INCLUDE_DIR` (`traces.h`), `Nauty_CORE_INCLUDE_DIR` (`nauty.h`), and `Nauty_LIBRARY`.

CMake fetches unmodified upstream headers and recursive submodules at the
exact revisions in [backend/pins.json](backend/pins.json). It verifies every revision and rejects
tracked modifications. No upstream source or executable is bundled here.
An existing clean pinned checkout can be used with
`-DFETCHCONTENT_SOURCE_DIR_POLYHEDRAL_COMMON=/absolute/path/to/polyhedral_common`.

To install the Julia package into another environment before registration:

```julia
using Pkg
Pkg.add(url="https://github.com/dimpase/PerfectForms.jl.git")
```

Build from that installed source into a writable directory with ordinary CMake:

```bash
perfect_forms_source="$(julia --project=. -e 'using PerfectForms; print(pkgdir(PerfectForms))')"
cmake -S "$perfect_forms_source" -B build/perfect-forms -G Ninja \
  -DCMAKE_BUILD_TYPE=Release '-DCMAKE_CXX_FLAGS_RELEASE=-O1 -DNDEBUG' \
  -DCMAKE_INSTALL_PREFIX="$PWD/backend-install"
cmake --build build/perfect-forms --parallel 1
ctest --test-dir build/perfect-forms --output-on-failure
cmake --install build/perfect-forms
export PERFECT_FORMS_BACKEND_CONFIG="$PWD/backend-install/config.json"
```

Use the environment containing PerfectForms with `--project=.` in that example.
This also works for read-only Julia package source directories. Set Homebrew
prefixes as above when configuring on macOS.

## Julia interface

```julia
using PerfectForms
result = enumerate_perfect_forms(5)
length(result.data["representatives"])  # 2
result.data["representatives"][1]["gram"]
result.run_directory                  # input, output, logs, process.json
result.process_info["elapsed_seconds"]
backend_build_info()["nauty_library"]
```

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
The result is a named tuple `(data, raw, run_directory, process_info)`.
`data` is parsed exact JSON: rational numbers, integer matrix entries and group
orders remain strings, preserving arbitrary precision. `raw` is the JSON text.

Configuration selects one absolute executable path and verifies its SHA256:

```julia
config = default_backend(config_path="/absolute/install/config.json")
result = enumerate_perfect_forms(12; config, timeout=180.0,
    work_dir="results/runs", memory_limit=10*1024^3)
```

`default_backend()` uses `PERFECT_FORMS_BACKEND_CONFIG` if set, otherwise this
checkout's `backend/config.json`. `BackendConfig("/absolute/path/to/executable")`
is available for an explicitly selected executable. Reinstall after rebuilding
or relocating a binary; do not edit recorded hashes to accept changed files.
`backend_build_info(config)` checks the installed `backend-build.json` against
the selected binary. For an uninstalled build, pass its provenance with `path=`.

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

## Tests and provenance

After installing the executable:

```bash
julia --startup-file=no --project=. -e 'using Pkg; Pkg.test()'
```

CTest exercises classical dimensions 2, 3 and 4, real quadratic discriminants
5, 8, 12, 13, 33 and 40, imaginary quadratic discriminants -3 and -4, a Raw
file-defined space and a rejected operation. These are regression examples,
not restrictions on accepted inputs. Published counts and their source
references are recorded in [test/reference_cases.json](test/reference_cases.json). Native checks also
verify exact Gram positivity, minimal-vector lengths, classical determinant
and stabilizer invariants, and the known imaginary Voronoi vertex counts.
The real quadratic D33 case has 149 orbits and provides a larger CI example.
Julia tests exercise the standalone interface, installation selection, SHA checks,
structured errors, deadlines, memory limits, stale/truncated output and paths
with spaces. CI runs these on Linux and macOS.

For a separate instrumented build:

```bash
cmake --preset sanitizer
cmake --build --preset sanitizer
ctest --preset sanitizer
python3 scripts/run_sanitizer.py --output-dir results/sanitizer
python3 scripts/run_sanitizer.py --fields --output-dir results/sanitizer_fields
```

ASan/UBSan instrument our exporter and instantiated upstream headers; linked
system libraries retain their own instrumentation. Do not impose an
address-space limit when running ASan. The Python driver retains raw exports
for optional independent validation; it is never used to configure or build.

This package was extracted from ArithmeticVoronoi commit
8f237bb9d311ee64f89b52d24da65ffe290cc5de. Our code retains its existing license
in [LICENSE](LICENSE). Upstream pins, attribution and reference license texts are in
[backend/NOTICE.txt](backend/NOTICE.txt) and `backend/`. Upstream code is fetched separately.
[backend/UPSTREAM_STATUS.txt](backend/UPSTREAM_STATUS.txt) reviews the resolutions of our three upstream
issues, the updated source pin and the parts of the JSON interface retained.
