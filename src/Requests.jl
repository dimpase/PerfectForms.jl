"""Build an input namelist for a supported rank-two perfect-form enumeration.

`D=1` selects binary rational forms. `D=5,8,12,13,40` selects the free rank-two
lattice over the maximal real quadratic order of discriminant `D`. Only the
GMP arithmetic path is implemented by the exporter; other safe arithmetic
names are accepted here to support explicit backend rejection diagnostics.
"""
function perfect_form_request(D::Integer=1;arithmetic="gmp")
    models=Dict(1=>(0,0),5=>(1,-1),8=>(0,-2),12=>(0,-3),13=>(1,-3),40=>(0,-10))
    haskey(models,D) || throw(ArgumentError("supported discriminants are 1 (classical rank two), 5, 8, 12, 13 and 40"))
    root_sum,root_product=models[D]
    arithmetic in ("gmp","flint","unsupported") || throw(ArgumentError("arithmetic name contains unsupported input characters"))
    """
    &TSPACE
      TypeTspace = "$(D==1 ? "Classic" : "RealQuad")"
      ClassicDim = 2
      RealImagDim = 2
      RealImagSum = $(root_sum)
      RealImagProd = $(root_product)
      SuperMatMethod = "NotNeeded"
      ListComm = "$(D==1 ? "Trivial" : "Use_realimag")"
      PtGroupMethod = "Trivial"
      FileListSubspaces = "unset"
    /
    &DATA
      arithmetic = "$arithmetic"
      OnlyWellRounded = T
      ComputeComplex = F
      ComputeBoundary = F
      ComputePreImage = F
      CacheFile = "none"
    /
    """
end

"""Enumerate perfect-form orbits, returning exact JSON data and process diagnostics.

Return `(data, raw, run_directory, process_info)`. Rational numbers and matrix
entries in `data` are exact strings, not floating-point approximations. This
checks the executable protocol and completion marker; independent mathematical
validation and arithmetic presentations are provided by ArithmeticVoronoi.
Resource and output keywords are passed to [`run_exporter`](@ref).
"""
function enumerate_perfect_forms(D::Integer=1;config=default_backend(),kwargs...)
    run_exporter(perfect_form_request(D),config;kwargs...)
end
