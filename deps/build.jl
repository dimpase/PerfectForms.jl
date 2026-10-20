using JSON3, SHA

include(joinpath(@__DIR__, "..", "src", "BuildPaths.jl"))

function build_backend()
    if lowercase(get(ENV, "PERFECT_FORMS_SKIP_BUILD", "false")) in ("true", "1")
        @info "Skipping the native build because PERFECT_FORMS_SKIP_BUILD is set"
        return
    end
    Sys.islinux() || Sys.isapple() ||
        error("PerfectForms supports native builds on Linux and macOS")
    cmake = Sys.which(get(ENV, "PERFECT_FORMS_CMAKE", "cmake"))
    isnothing(cmake) && error("Install CMake 3.24 or newer, then run Pkg.build(\"PerfectForms\"; verbose=true)")
    jobs = tryparse(Int, get(ENV, "PERFECT_FORMS_BUILD_JOBS", "1"))
    if isnothing(jobs) || jobs < 1
        error("PERFECT_FORMS_BUILD_JOBS must be a positive integer")
    end

    package_root = realpath(joinpath(@__DIR__, ".."))
    state = BuildPaths.state_directory(package_root)
    selection_path = BuildPaths.selection_file(package_root)
    source = get(ENV, "PERFECT_FORMS_BACKEND_SOURCE", nothing)
    if isnothing(source)
        previous = isfile(selection_path) ? JSON3.read(read(selection_path, String)) : nothing
        source = isnothing(previous) ? "" : get(previous, "backend_source", "")
        source isa AbstractString || error("Invalid saved backend source; set PERFECT_FORMS_BACKEND_SOURCE explicitly")
    end
    if !isempty(source)
        source = expanduser(source)
        isabspath(source) && isdir(source) ||
            error("PERFECT_FORMS_BACKEND_SOURCE must name an existing absolute upstream checkout")
        source = realpath(source)
    end
    variant = isempty(source) ? "pinned" : "local-" * bytes2hex(sha256(source))
    build_dir = joinpath(state, variant, "build")
    prefix = joinpath(state, variant, "install")
    @info "Building PerfectForms" source=(isempty(source) ? "pinned upstream sources" : source) build_dir prefix jobs

    options = [
        "-DCMAKE_BUILD_TYPE=Release",
        "-DCMAKE_CXX_FLAGS_RELEASE=-O1 -DNDEBUG",
        "-DCMAKE_INSTALL_PREFIX=$prefix",
        "-DBUILD_TESTING=ON",
        "-DAV_BACKEND_DEVELOPMENT=$(isempty(source) ? "OFF" : "ON")",
        "-DFETCHCONTENT_SOURCE_DIR_POLYHEDRAL_COMMON=$source",
    ]
    run(`$cmake -S $package_root -B $build_dir $options`)
    run(`$cmake --build $build_dir --parallel $jobs`)
    run(`$cmake --install $build_dir --prefix $prefix`)

    # Publish the selection only after a successful install. No generated file
    # is written into the package source directory.
    selection = Dict(
        "schema" => "perfect_forms_build_selection_v1",
        "config_path" => joinpath(prefix, "config.json"),
        "build_directory" => build_dir,
        "backend_source" => source,
    )
    path = selection_path
    temporary, io = mktemp(dirname(path))
    try
        JSON3.pretty(io, selection)
        println(io)
        close(io)
        Base.Filesystem.rename(temporary, path)
    finally
        isopen(io) && close(io)
        isfile(temporary) && rm(temporary)
    end
    @info "PerfectForms backend installed" config=selection["config_path"]
end

build_backend()
