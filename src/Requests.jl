function namelist_value(value::AbstractString)
    any(c->iscntrl(c) || c=='!',value) &&
        throw(ArgumentError("namelist strings cannot contain control characters or the upstream comment character !"))
    delimiter=!occursin('"',value) ? '"' : !occursin('\'',value) ? '\'' :
        throw(ArgumentError("upstream namelist strings cannot contain both quote delimiters"))
    string(delimiter,value,delimiter)
end
namelist_value(value::Bool)=value ? "T" : "F"
namelist_value(value::Integer)=string(value)
function namelist_value(value::AbstractFloat)
    isfinite(value) || throw(ArgumentError("namelist numbers must be finite"))
    string(value)
end
namelist_value(value::AbstractVector)=join(namelist_value.(value),", ")
namelist_value(value)=throw(ArgumentError("unsupported namelist value type: $(typeof(value))"))

function namelist_block(io,name,defaults,options)
    values=Dict{String,Any}(defaults)
    for (key,value) in pairs(options)
        key=string(key)
        occursin(r"^[A-Za-z][A-Za-z0-9_]*$",key) || throw(ArgumentError("invalid namelist key: $key"))
        values[key]=value
    end
    println(io,"&",name)
    for key in sort!(collect(keys(values)))
        println(io,"  ",key," = ",namelist_value(values[key]))
    end
    println(io,"/")
end

"""Build a perfect-form enumeration request from upstream T-space options.

`tspace` and `data` accept a named tuple or dictionary using upstream option
names. T-space types, dimensions, field polynomials and file inputs are passed
to upstream without a package-specific whitelist. Use absolute paths for
auxiliary files: the child runs in a private request directory.

The default selects classical binary forms and GMP arithmetic. The compiled
exporter implements perfect-form/facet enumeration, not lower complexes.
"""
function perfect_form_request(;tspace=(TypeTspace="Classic",ClassicDim=2),data=(;))
    io=IOBuffer()
    namelist_block(io,"TSPACE",Dict("SuperMatMethod"=>"NotNeeded","ListComm"=>"Trivial",
        "PtGroupMethod"=>"Trivial","FileListSubspaces"=>"unset"),tspace)
    namelist_block(io,"DATA",Dict{String,Any}("arithmetic"=>"gmp","OnlyWellRounded"=>true,
        "ComputeComplex"=>false,"ComputeBoundary"=>false,"ComputePreImage"=>false,
        "CacheFile"=>"none"),data)
    String(take!(io))
end

"""Build a request for a quadratic order of discriminant `D`, in any rank.

Use `D=1` for classical rational forms. Positive and negative nonsquare
discriminants congruent to 0 or 1 modulo 4 select real and imaginary quadratic
orders, respectively. Fundamental discriminants select maximal orders; a
nonfundamental discriminant describes the corresponding nonmaximal order.
`dimension` defaults to two. No list of tested fields limits accepted inputs.
Use the keyword-only method for an arbitrary upstream T-space description.
"""
function perfect_form_request(D::Integer;dimension::Integer=2,arithmetic="gmp")
    dimension>0 || throw(ArgumentError("dimension must be positive"))
    if D==1
        return perfect_form_request(;tspace=(TypeTspace="Classic",ClassicDim=dimension),
            data=(;arithmetic))
    end
    D!=0 && mod(D,4) in (0,1) && (D<0 || isqrt(D)^2!=D) ||
        throw(ArgumentError("a nonsquare quadratic-order discriminant congruent to 0 or 1 modulo 4 is required"))
    root_sum=mod(D,4)==1 ? 1 : 0
    root_product=div(root_sum-big(D),4) # root_sum is either 0 or 1, so root_sum^2=root_sum.
    perfect_form_request(;tspace=(TypeTspace=D>0 ? "RealQuad" : "ImagQuad",
        RealImagDim=dimension,RealImagSum=root_sum,RealImagProd=root_product,
        ListComm="Use_realimag"),data=(;arithmetic))
end

"""Enumerate perfect forms from an upstream namelist or quadratic discriminant.

`enumerate_perfect_forms(input_text; config, ...)` passes a namelist unchanged
to the exporter. `enumerate_perfect_forms(D; dimension=2, config, ...)` uses
the quadratic-order convenience constructor; `D=1` selects classical forms.
With no positional argument, pass upstream options as `tspace` and `data`.

Return `(data, raw, run_directory, process_info)` after checking the process
and export protocol. Exact numeric values remain JSON strings. Mathematical
validation is the caller's responsibility. Remaining keywords control
[`run_exporter`](@ref), including its deadline and memory budget.
"""
function enumerate_perfect_forms(input_text::AbstractString;config=default_backend(),kwargs...)
    run_exporter(input_text,config;kwargs...)
end
function enumerate_perfect_forms(D::Integer;dimension::Integer=2,arithmetic="gmp",
                                 config=default_backend(),kwargs...)
    run_exporter(perfect_form_request(D;dimension,arithmetic),config;kwargs...)
end
function enumerate_perfect_forms(;tspace=(TypeTspace="Classic",ClassicDim=2),data=(;),
                                 config=default_backend(),kwargs...)
    run_exporter(perfect_form_request(;tspace,data),config;kwargs...)
end
