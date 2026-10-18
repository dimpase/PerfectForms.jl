"""Select a CMake-installed exporter.

Set `PERFECT_FORMS_BACKEND_CONFIG` to the absolute path of an installed
`config.json`, or pass `config_path` explicitly. Without an override, use the
installation in this package checkout's `backend/` directory. Loading the Julia
package does not download sources or compile C++.
"""
function default_backend(;config_path=get(ENV,"PERFECT_FORMS_BACKEND_CONFIG",
                                         joinpath(PACKAGE_ROOT,"backend","config.json")))
    isabspath(config_path) || throw(BackendError(:invalid_configuration,"config.json needs an absolute path"))
    isfile(config_path) || throw(BackendError(:missing_executable,
        "build and install PerfectForms with CMake, then set PERFECT_FORMS_BACKEND_CONFIG to its config.json, or pass BackendConfig(absolute_path)"))
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
