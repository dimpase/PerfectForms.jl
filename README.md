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

## Requirements

Julia 1.10 or newer, Git, CMake 3.24+, Make or Ninja, `pkg-config`,
a C++20 compiler and standard library with `std::format`, and development
headers/libraries for GMP, Eigen 3, Boost.Serialization and nauty/Traces.
Python 3.8+ is used only for tests. Linux runtime memory limits use `prlimit`
from util-linux; macOS uses the system `ps` command.

Install these dependencies with your system package manager. On macOS, install
current Xcode Command Line Tools and run:

```bash
brew install cmake ninja pkgconf gmp eigen@3 boost nauty
export CMAKE_PREFIX_PATH="$(brew --prefix eigen@3):$(brew --prefix)"
```

## Install and run from a checkout

CMake builds and installs the C++ executable. Julia loads the Julia package
from its project environment. Build and install the backend, then load the
Julia package as follows.

### 1. Build the backend

For a new checkout:

```bash
git clone https://github.com/dimpase/PerfectForms.jl.git
cd PerfectForms.jl
```

For an existing checkout, enter its root instead, for example
`cd ~/work/tmp/PerfectForms.jl`. All shell commands in this section run from
that directory, beside `Project.toml` and `CMakeLists.txt`.

If you have already successfully built `build/bin/AV_ExportPerfectOrbits`,
continue with step 2. Otherwise:

```bash
cmake -S . -B build \
  -DCMAKE_BUILD_TYPE=Release \
  '-DCMAKE_CXX_FLAGS_RELEASE=-O1 -DNDEBUG' \
  -DCMAKE_INSTALL_PREFIX="$PWD/backend"
cmake --build build --parallel 1
```

The first configure downloads the pinned backend and recursive submodules after
nauty detection; this can take several minutes. Progress and timings identify
this stage. Subsequent configures reuse those sources.

### 2. Install the built backend

```bash
cmake --install build --prefix "$PWD/backend"
```

Use an **absolute** prefix, as above. `--prefix backend/` records a relative
executable path in the generated configuration, which the Julia interface rejects.
This command also overrides `/usr/local` if that was the cached install prefix.
It installs under your checkout and needs no administrator privileges.

The installed files include:

| Path relative to the checkout | Purpose |
| --- | --- |
| `backend/bin/AV_ExportPerfectOrbits` | Native executable |
| `backend/config.json` | Absolute executable path, SHA256 and upstream revision |
| `backend/backend-build.json` | Build and dependency information |

Re-run the install command after rebuilding or moving the installation to
regenerate the paths and hashes.

### 3. Load the Julia package and run a computation

Still in the checkout, run these **shell** commands:

```bash
unset PERFECT_FORMS_BACKEND_CONFIG
julia --startup-file=no --project=. -e 'using Pkg; Pkg.instantiate()'
julia --startup-file=no --project=.
```

The `unset` removes any earlier backend override. The package then uses
`backend/config.json` inside the checkout Julia loads. `Pkg.instantiate()`
installs the Julia dependencies, and `--project=.` selects this checkout's
environment. See the [Julia environment documentation](https://pkgdocs.julialang.org/v1/environments/).

At the **Julia** prompt:

```julia
using PerfectForms

pkgdir(PerfectForms)            # the checkout you selected
default_backend().executable    # <checkout>/backend/bin/AV_ExportPerfectOrbits

result = enumerate_perfect_forms(5)
length(result.data["representatives"])  # 2
```

To start Julia from another directory while using this same environment, give
the checkout's path explicitly, for example:

```bash
julia --startup-file=no --project="$HOME/work/tmp/PerfectForms.jl"
```

## Use this checkout from another Julia project

Register the local checkout in the Julia environment that will use it. For your
default environment, start plain `julia --startup-file=no`. For an application
project, start `julia --startup-file=no --project=/absolute/path/to/your/project`.
Select one of those environments before running:

```julia
using Pkg
Pkg.develop(path=expanduser("~/work/tmp/PerfectForms.jl"))
using PerfectForms
pkgdir(PerfectForms)
```

Adjust the checkout path if you cloned elsewhere. `Pkg.develop` records that
directory in the active environment and installs its Julia dependencies.
Keep the checkout at that location. In subsequent sessions using the same
environment, load it with `using PerfectForms`.
See [developing a local Julia package](https://pkgdocs.julialang.org/v1/managing-packages/#Developing-packages).

The backend installed in that checkout's `backend/` remains the default.
Julia package operations and `using PerfectForms` do not build or install C++.

## Select the backend configuration

Set `PERFECT_FORMS_BACKEND_CONFIG` to the **absolute path of the installed
`config.json` file**. A value ending in `/backend` names a directory and causes the
`missing_executable: build and install PerfectForms...` error even when the
executable has been installed.

For example, to select the checkout's installed backend explicitly, run in the
**shell before starting Julia**:

```bash
export PERFECT_FORMS_BACKEND_CONFIG="$HOME/work/tmp/PerfectForms.jl/backend/config.json"
```

For an **already-running Julia session**, change its own environment instead:

```julia
ENV["PERFECT_FORMS_BACKEND_CONFIG"] =
    expanduser("~/work/tmp/PerfectForms.jl/backend/config.json")
isfile(ENV["PERFECT_FORMS_BACKEND_CONFIG"])  # true
default_backend().executable
```

Shell changes do not update the environment of an already-running Julia
process. To return that session to automatic lookup, run:

```julia
delete!(ENV, "PERFECT_FORMS_BACKEND_CONFIG")
default_backend().executable
```

Lookup order is an explicit `config_path` argument, then
`ENV["PERFECT_FORMS_BACKEND_CONFIG"]` if set, then
`backend/config.json` in the loaded PerfectForms package directory.
Use `expanduser` for `~` in Julia paths; a literal `"~/..."` is not absolute.

This selector also lets another copy of PerfectForms, such as an
ArithmeticVoronoi dependency, use an existing backend with the matching upstream
revision. To install in a separate location, run from the built checkout:

```bash
cmake --install build --prefix "$HOME/.local/opt/perfectforms"
export PERFECT_FORMS_BACKEND_CONFIG="$HOME/.local/opt/perfectforms/config.json"
```

## Troubleshooting installation and loading

Inspect the path selected in the **Julia session that reports the error**:

```julia
using PerfectForms
selector = get(ENV, "PERFECT_FORMS_BACKEND_CONFIG",
               joinpath(pkgdir(PerfectForms), "backend", "config.json"))
@show pkgdir(PerfectForms)
@show selector isabspath(selector) isfile(selector)
```

The last two values should both be `true`.

| Error | What to check |
| --- | --- |
| Julia cannot find `PerfectForms` | Start with `--project=` pointing to the checkout, or use `Pkg.develop` in the consuming environment. |
| `config.json needs an absolute path` | The selector is relative. Use an absolute filename, or remove the override to use the default. |
| `missing_executable: build and install PerfectForms...` | The selected config file is absent or is a directory. Check that the path ends in `/config.json`; run step 2 if the file has not been installed. |
| `invalid_executable: configure one absolute executable path` | The executable path inside the config is relative. Reinstall using the absolute prefix in step 2. |
| `executable hash differs from its configured build` | Reinstall the rebuilt executable to regenerate its configuration and hash. |

## Build options

CMake uses `pkg-config`, `CMAKE_PREFIX_PATH` and ordinary header/library searches
to locate dependencies. An installed nauty is required. If necessary, specify
`Nauty_INCLUDE_DIR` (`traces.h`), `Nauty_CORE_INCLUDE_DIR` (`nauty.h`) and
`Nauty_LIBRARY` when configuring.

Build serially to limit compiler memory. On Linux, you can prefix the build
command with `prlimit --as=10737418240` for a 10 GiB address-space limit.
The `release` preset provides a Ninja build with the same `-O1` setting and
`backend/` install prefix. Use it with a fresh build directory; a directory
already configured for Make must keep its generator.

CMake fetches unmodified upstream headers and recursive submodules at the exact
revisions in [backend/pins.json](backend/pins.json). It verifies every revision
and rejects tracked modifications. No upstream source or executable is bundled
here. Use `-DAV_BACKEND_FETCH_PROGRESS=OFF` to disable extra fetch output; stage
messages and timings remain. An existing clean pinned checkout can be used with
`-DFETCHCONTENT_SOURCE_DIR_POLYHEDRAL_COMMON=/absolute/path/to/polyhedral_common`.

<details>
<summary>Build a package installed with Pkg.add, using separate writable directories</summary>

In the consuming Julia project:

```julia
using Pkg
Pkg.add(url="https://github.com/dimpase/PerfectForms.jl.git")
```

Then, in a shell at that project's root:

```bash
perfect_forms_source="$(julia --startup-file=no --project=. -e 'using PerfectForms; print(pkgdir(PerfectForms))')"
cmake -S "$perfect_forms_source" -B build/perfect-forms \
  -DCMAKE_BUILD_TYPE=Release '-DCMAKE_CXX_FLAGS_RELEASE=-O1 -DNDEBUG' \
  -DCMAKE_INSTALL_PREFIX="$PWD/backend-install"
cmake --build build/perfect-forms --parallel 1
cmake --install build/perfect-forms --prefix "$PWD/backend-install"
export PERFECT_FORMS_BACKEND_CONFIG="$PWD/backend-install/config.json"
julia --startup-file=no --project=.
```

At the Julia prompt, run `using PerfectForms`, then
`default_backend().executable` and the computation in step 3. This workflow
also supports read-only package source directories. On macOS, set
`CMAKE_PREFIX_PATH` as described under Requirements before configuring.

</details>

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

`BackendConfig("/absolute/path/to/executable")` is also available for an
explicitly selected executable. Backend selection is described above.
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

After installing the executable, run from the checkout:

```bash
unset PERFECT_FORMS_BACKEND_CONFIG
ctest --test-dir build --output-on-failure
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

AI assistance was used for the CMake fetch diagnostics, installation
documentation and registration setup.

## Releasing

Maintainer instructions for registering a release in Julia's General registry
are in [.github/RELEASING.md](.github/RELEASING.md).
