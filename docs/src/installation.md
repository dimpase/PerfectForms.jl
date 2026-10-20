# Installation

PerfectForms runs on Linux and macOS with Julia 1.10 or newer. On first
installation, Julia's `Pkg` runs `deps/build.jl` to compile and install the C++
backend using CMake. Install the native prerequisites before adding the package.
A prebuilt backend is not supplied yet.

## Native prerequisites

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

## Install and run

Start in a writable application directory, for example:

```bash
mkdir -p ~/perfectforms-example
cd ~/perfectforms-example
julia --startup-file=no --project=.
```

Once [registration in General](https://github.com/JuliaRegistries/General/pull/172562)
merges, run at the Julia prompt:

```julia
using Pkg
Pkg.add("PerfectForms")
```

Until registration merges, replace the `Pkg.add` line with:

```julia
Pkg.add(url="https://github.com/dimpase/PerfectForms.jl.git")
```

The first build obtains the pinned upstream sources and recursive submodules,
compiles serially, and installs in a Julia-managed scratch directory. This can
take several minutes. `Pkg` prints the build log's location; on failure it also
prints the log. Later builds reuse the downloaded sources and build directory.
Build products do not need a writable package source directory or administrator
privileges. `default_backend()` finds the installed executable automatically.

```julia
using PerfectForms
default_backend().executable
result = enumerate_perfect_forms(5)
length(result.data["representatives"]) # 2
```

Start subsequent sessions with `julia --project=.` in the same application
directory. `using PerfectForms` loads the package without running a build.
An existing nonempty `PERFECT_FORMS_BACKEND_CONFIG` override still takes precedence;
unset it or set it to an empty string to use the automatic installation.
See [Backend configuration](configuration.md).

## Rebuild or retry

After installing a missing prerequisite, or to rebuild with visible progress:

```julia
using Pkg
Pkg.build("PerfectForms"; verbose=true)
```

CMake progress, source inspection and compiler output are then printed in the
terminal. Each successful build refreshes executable paths, hashes and provenance.
For [local C++ development](development.md), use `Pkg.develop` and an optional
local upstream checkout. Source selections are remembered per package checkout.

## Build settings

Set these environment variables before `Pkg.add` or `Pkg.build`:

| Variable | Purpose |
| --- | --- |
| `PERFECT_FORMS_BACKEND_SOURCE` | Absolute local `polyhedral_common` Git checkout, including its submodules. Allows local revisions and patches. The successful choice is remembered; set it to an empty string to return to pinned sources. |
| `PERFECT_FORMS_BUILD_JOBS` | Positive number of compiler jobs; default `1` limits memory use. |
| `PERFECT_FORMS_CMAKE` | CMake executable name or absolute path; default `cmake`. |
| `PERFECT_FORMS_SKIP_BUILD` | Set to `true` to skip native compilation, for example when building documentation or using an existing manual backend. |

An explicit local source path is used without fetching or changing that checkout.
If a remembered checkout is missing, the build fails instead of substituting a
download. `CMAKE_PREFIX_PATH` and normal CMake compiler environment settings can
be used when first configuring a build. For full control over toolchain and
cache options, use the [manual CMake workflow](development.md).

To reuse an already installed compatible backend, set
`PERFECT_FORMS_SKIP_BUILD=true` before package installation and select its
absolute `config.json` path as described in [Backend configuration](configuration.md).
Unset `PERFECT_FORMS_SKIP_BUILD` before requesting a native rebuild.
