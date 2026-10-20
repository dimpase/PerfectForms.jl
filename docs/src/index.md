# PerfectForms.jl

PerfectForms enumerates perfect-form orbits using Mathieu Dutour Sikirić's
[polyhedral_common](https://github.com/MathieuDutSik/polyhedral_common) C++ code.
The Julia interface returns exact forms, minimal vectors, stabilizers, facet
orbits and labelled neighbours. It needs neither Oscar nor GAP.

Start with [Installation](installation.md), then [Usage](usage.md) for a first
computation. [Backend configuration](configuration.md) covers reusing an
installation and diagnosing path errors. [Development](development.md) covers
source checkouts, build options and tests. The [API reference](api.md) contains
the public Julia docstrings.

## Scope

The exporter accepts upstream T-space descriptions, including classical forms,
real and imaginary quadratic forms, group-invariant spaces and spaces supplied
by matrix files. Fields and dimensions are not restricted to the regression
examples. Its compiled arithmetic path uses exact GMP integers and rationals;
requests for other arithmetic paths are reported explicitly.

The wrapper checks the executable, process and export protocol. Independent
mathematical validation belongs in the caller.
[ArithmeticVoronoi](https://github.com/dimpase/arithmetic_voronoi) provides exact
validation, two-cells, GL/SL/PSL presentations and constructive matrix-to-word
algorithms.

## First computation

After installation has built the backend:

```julia
using PerfectForms
result = enumerate_perfect_forms(5)
length(result.data["representatives"]) # 2
```

## Provenance

PerfectForms was extracted from ArithmeticVoronoi commit
`8f237bb9d311ee64f89b52d24da65ffe290cc5de`. Package licensing and upstream
attribution are recorded in
[LICENSE](https://github.com/dimpase/PerfectForms.jl/blob/main/LICENSE) and
[backend/NOTICE.txt](https://github.com/dimpase/PerfectForms.jl/blob/main/backend/NOTICE.txt).
Upstream source is fetched separately at verified revisions; see
[backend/pins.json](https://github.com/dimpase/PerfectForms.jl/blob/main/backend/pins.json)
and the [upstream status report](https://github.com/dimpase/PerfectForms.jl/blob/main/backend/UPSTREAM_STATUS.txt).
