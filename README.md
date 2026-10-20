# PerfectForms.jl

Enumerate perfect-form orbits from Julia using Mathieu Dutour Sikirić's
[polyhedral_common](https://github.com/MathieuDutSik/polyhedral_common).
Results contain exact forms, minimal vectors, stabilizers, facet orbits and
labelled neighbours. Classical, quadratic and general upstream T-spaces are
supported; neither Oscar nor GAP is required.

## Installation

Requires Julia 1.10 or newer on Linux or macOS and the
[native build prerequisites](docs/src/installation.md). Once
[registration in General](https://github.com/JuliaRegistries/General/pull/172562)
merges, install in your Julia environment with:

```julia
using Pkg
Pkg.add("PerfectForms")
```

Until then, use `Pkg.add(url="https://github.com/dimpase/PerfectForms.jl.git")`.
Installation builds the C++ backend automatically with CMake. See
[Installation](docs/src/installation.md) for prerequisites and rebuilding.

## Example

```julia
using PerfectForms
result = enumerate_perfect_forms(5)    # Q(sqrt(5)), rank two
length(result.data["representatives"]) # 2
result.data["representatives"][1]["gram"]
```

See the [manual](docs/src/index.md) for [usage](docs/src/usage.md),
[backend configuration](docs/src/configuration.md),
[development](docs/src/development.md) and the [API reference](docs/src/api.md).
[ArithmeticVoronoi](https://github.com/dimpase/arithmetic_voronoi) adds independent
exact validation, group presentations and constructive matrix-to-word algorithms.

Licensed under [GPL-3.0](LICENSE); see [upstream notices](backend/NOTICE.txt).
AI assistance was used for CMake fetch diagnostics, documentation and registration setup.
