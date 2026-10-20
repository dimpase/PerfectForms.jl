# Development

Install the [native prerequisites](installation.md) first.

## Work on a local PerfectForms checkout

In the Julia environment that will use the package:

```julia
using Pkg
Pkg.develop(path=expanduser("~/work/tmp/PerfectForms.jl"))
Pkg.build("PerfectForms"; verbose=true)
using PerfectForms
pkgdir(PerfectForms)
default_backend().executable
```

Adjust the checkout path as needed. `Pkg.develop` tracks the working directory,
including uncommitted Julia and C++ edits. It does not itself compile the backend;
run `Pkg.build` explicitly. Our exporter is `backend/export_perfect.cpp` in this
checkout. After editing it, repeat `Pkg.build("PerfectForms"; verbose=true)`.

Alternatively, work directly in the package's own environment:

```bash
cd ~/work/tmp/PerfectForms.jl
julia --startup-file=no --project=. -e 'using Pkg; Pkg.resolve(); Pkg.instantiate(); Pkg.build(; verbose=true)'
julia --startup-file=no --project=.
```

`Pkg.resolve()` updates an existing local manifest after package dependencies
change. If you previously selected an external `config.json`, remove that override
to use the build produced here. Existing `BackendConfig` objects retain the old
executable hash; obtain a fresh `default_backend()` after rebuilding.

## Work on local upstream C++ sources

Use a separate `polyhedral_common` Git checkout with its recursive submodules
already initialized. Set its absolute path in Julia before building:

```julia
ENV["PERFECT_FORMS_BACKEND_SOURCE"] = expanduser("~/work/polyhedral_common")
Pkg.build("PerfectForms"; verbose=true)
```

This builds directly from the local working tree, including uncommitted patches
and different revisions. It does not fetch, reset, clean, or check out files in
that directory. The source choice is remembered after a successful build, so
later sessions can rebuild the same patched source with:

```julia
using Pkg
Pkg.build("PerfectForms"; verbose=true)
```

Incremental builds reuse their build directory. Distinct PerfectForms checkouts
have separate scratch installations, and local upstream sources have separate
build directories from the pinned default. Returning to the pinned sources is
explicit:

```julia
ENV["PERFECT_FORMS_BACKEND_SOURCE"] = ""
Pkg.build("PerfectForms"; verbose=true)
```

Build metadata records the actual upstream and submodule commits, whether their
working trees have modifications, and hashes of tracked and nonignored new
files. `backend_build_info()` exposes this as `source_provenance` and
`source_sha256`; exports also carry `backend_source_sha256`. Expected release
pins remain separately recorded under `dependency_pins`.

## Manual CMake build

To manage a native build directly, run from the PerfectForms checkout:

```bash
cmake -S . -B build \
  -DCMAKE_BUILD_TYPE=Release \
  '-DCMAKE_CXX_FLAGS_RELEASE=-O1 -DNDEBUG' \
  -DCMAKE_INSTALL_PREFIX="$PWD/backend"
cmake --build build --parallel 1
cmake --install build --prefix "$PWD/backend"
export PERFECT_FORMS_BACKEND_CONFIG="$PWD/backend/config.json"
PERFECT_FORMS_SKIP_BUILD=true julia --startup-file=no --project=. -e 'using Pkg; Pkg.resolve(); Pkg.instantiate()'
julia --startup-file=no --project=.
```

The first configure obtains pinned sources after nauty detection and reports
progress. If `build/bin/AV_ExportPerfectOrbits` is already built, start at the
install command. Use an **absolute** install prefix: `--prefix backend/` records
a relative executable path, which Julia rejects. The absolute `--prefix` also
overrides a previously cached `/usr/local` destination.

The prefix contains `bin/AV_ExportPerfectOrbits`, `config.json` and
`backend-build.json`. Reinstall after rebuilding or moving the installation to
regenerate paths and hashes. The explicit environment variable selects this
manual installation even if a scratch installation also exists.

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
revisions in [backend/pins.json](https://github.com/dimpase/PerfectForms.jl/blob/main/backend/pins.json). In pinned mode it verifies every revision
and rejects local modifications. No upstream source or executable is bundled
here. Use `-DAV_BACKEND_FETCH_PROGRESS=OFF` to disable extra fetch output; stage
messages and timings remain. An existing clean pinned checkout can be used with
`-DFETCHCONTENT_SOURCE_DIR_POLYHEDRAL_COMMON=/absolute/path/to/polyhedral_common`.
To build a patched or different revision from that explicit checkout, also set
`-DAV_BACKEND_DEVELOPMENT=ON`. Development mode requires a local source override.
The checkout and required submodules must already be initialized.

## Tests

After a successful `Pkg.build`, run from the package checkout:

```bash
julia --startup-file=no --project=. -e 'using Pkg; Pkg.test()'
```

Native tests can be run against the same build from Julia:

```julia
using PerfectForms
build_dir = backend_build_info()["build_directory"]
run(`ctest --test-dir $build_dir --output-on-failure`)
```

For a manual CMake build, use `ctest --test-dir build --output-on-failure`.

CTest exercises classical dimensions 2, 3 and 4, real quadratic discriminants
5, 8, 12, 13, 33 and 40, imaginary quadratic discriminants -3 and -4, a Raw
file-defined space and a rejected operation. These are regression examples,
not restrictions on accepted inputs. Published counts and their source
references are recorded in [test/reference_cases.json](https://github.com/dimpase/PerfectForms.jl/blob/main/test/reference_cases.json). Native checks also
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

## Build the documentation

From the repository root, install the separate documentation environment and
build the manual:

```bash
PERFECT_FORMS_SKIP_BUILD=true julia --startup-file=no --project=docs -e 'using Pkg; Pkg.develop(path="."); Pkg.instantiate()'
julia --startup-file=no --project=docs docs/make.jl
```

The HTML is written to `docs/build/`. Building the documentation does not need
the C++ backend: computation examples are displayed as code, and the request
constructor example is doctested without launching an executable. Documenter
checks internal links and includes the public API docstrings.

To browse with a local web server, install LiveServer in a temporary Julia
environment and serve the generated files (run from the repository root):

```bash
julia --startup-file=no -e 'using Pkg; Pkg.activate(; temp=true); Pkg.add("LiveServer"); using LiveServer; serve(dir="docs/build")'
```

Open the address printed by LiveServer; stop the server with Ctrl-C.
`docs/build/` and `docs/Manifest.toml` are generated and ignored by Git.

## Documentation hosting and releases

The Documentation workflow builds on pull requests, pushes to `main` and version
tags. On pushes it publishes the generated manual to the `gh-pages` branch.
After the first successful run, enable GitHub Pages for `gh-pages` and its root
folder in the repository's **Settings → Pages**. The development manual will
then be at `https://dimpase.github.io/PerfectForms.jl/dev/`; `stable/` is created
when a version tag is built. The README links to source pages so those links
also work before hosting is enabled.

TagBot is configured to tag registered versions automatically. To have those
tags trigger the Documentation workflow, configure its optional
`DOCUMENTER_KEY` SSH deploy key, following
[Documenter's instructions](https://documenter.juliadocs.org/stable/man/hosting/#Authentication:-SSH-Deploy-Keys).
Without that key, TagBot can create ordinary releases with `GITHUB_TOKEN`, but
its tags do not trigger other workflows. In that case, run the Documentation
workflow manually with the release tag selected to publish versioned docs.

See the [release guide](https://github.com/dimpase/PerfectForms.jl/blob/main/.github/RELEASING.md)
for registration and TagBot setup. Keep workflow changes separate from the
commit submitted for registration: GitHub restricts token-based releases of
commits that change workflow files.
