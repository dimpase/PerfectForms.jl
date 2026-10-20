# API reference

```@meta
CurrentModule = PerfectForms
```

## Enumeration and requests

```@docs
enumerate_perfect_forms
perfect_form_request
```

Request construction does not require an installed backend:

```jldoctest
julia> using PerfectForms

julia> request = perfect_form_request(5);

julia> occursin("RealQuad", request)
true

julia> occursin("ComputeComplex = F", request)
true
```

## Backend selection and execution

```@docs
BackendConfig
default_backend
backend_build_info
run_exporter
BackendError
```
