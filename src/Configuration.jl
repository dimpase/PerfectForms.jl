function default_config_path()
    override=get(ENV,"PERFECT_FORMS_BACKEND_CONFIG","")
    !isempty(override) && return override
    selection=BuildPaths.selection_file(PACKAGE_ROOT)
    if isfile(selection)
        data=try JSON3.read(read(selection,String),Dict{String,Any}) catch err
            throw(BackendError(:invalid_configuration,"invalid build selection: "*sprint(showerror,err)))
        end
        get(data,"schema",nothing)=="perfect_forms_build_selection_v1" &&
            get(data,"config_path",nothing) isa AbstractString ||
            throw(BackendError(:invalid_configuration,"invalid build selection: $selection"))
        return data["config_path"]
    end
    joinpath(PACKAGE_ROOT,"backend","config.json")
end

"""Select an installed exporter.

Set `PERFECT_FORMS_BACKEND_CONFIG` to the absolute path of an installed
`config.json`, or pass `config_path` explicitly. Otherwise use the last successful
`Pkg.build("PerfectForms")` installation for this package checkout/version,
falling back to the checkout's `backend/config.json` for manual CMake installs.
An unset or empty environment variable uses this automatic selection.
Loading the Julia package does not download sources or compile C++.
"""
function default_backend(;config_path=default_config_path())
    isabspath(config_path) || throw(BackendError(:invalid_configuration,"config.json needs an absolute path"))
    isfile(config_path) || throw(BackendError(:missing_executable,
        "run Pkg.build(\"PerfectForms\"; verbose=true), or set PERFECT_FORMS_BACKEND_CONFIG to an installed config.json file"))
    data=try JSON3.read(read(config_path,String),Dict{String,Any}) catch err
        throw(BackendError(:invalid_configuration,sprint(showerror,err)))
    end
    get(data,"schema",nothing)=="av_backend_config_v1" ||
        throw(BackendError(:invalid_configuration,"unsupported backend configuration schema"))
    all(k->get(data,k,nothing) isa AbstractString,("executable","executable_sha256","commit")) ||
        throw(BackendError(:invalid_configuration,"missing executable, SHA256 or commit in backend configuration"))
    BackendConfig(data["executable"];expected_sha256=data["executable_sha256"],commit=data["commit"])
end

"""Read CMake build provenance, checking that it describes the selected executable.

`path` defaults to the provenance installed beside the executable's `bin/`
directory. For an uninstalled build, pass its `backend-build.json` explicitly.
"""
function backend_build_info(B::BackendConfig=default_backend();
                            path=joinpath(dirname(dirname(B.executable)),"backend-build.json"))
    data=try JSON3.read(read(path,String),Dict{String,Any}) catch err
        throw(BackendError(:invalid_configuration,sprint(showerror,err)))
    end
    get(data,"schema",nothing)=="av_backend_build_v1" ||
        throw(BackendError(:invalid_configuration,"unsupported backend build provenance schema"))
    get(data,"executable_sha256",nothing)==B.executable_sha256 &&
        get(data,"commit",nothing)==B.commit && file_sha(B.executable)==B.executable_sha256 ||
        throw(BackendError(:incompatible_backend,"build provenance differs from the selected executable"))
    data
end
