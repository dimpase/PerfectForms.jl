module PerfectForms

using JSON3, SHA, Dates

export BackendConfig, BackendError, default_backend, run_exporter, backend_build_info,
       perfect_form_request, enumerate_perfect_forms

const PACKAGE_ROOT=normpath(joinpath(@__DIR__,".."))
include_dependency(joinpath(PACKAGE_ROOT,"backend","pins.json"))
const BACKEND_COMMIT=JSON3.read(read(joinpath(PACKAGE_ROOT,"backend","pins.json"),String))["commit"]

"""
    BackendError

Backend failure with a symbolic `kind`, a human-readable `message`, and a
`run_directory` containing diagnostics when a request directory was created.
"""
struct BackendError <: Exception
    kind::Symbol
    message::String
    run_directory::String
end
BackendError(kind,message)=BackendError(kind,message,"")
Base.showerror(io::IO,e::BackendError)=print(io,e.kind,": ",e.message,isempty(e.run_directory) ? "" : " (diagnostics: $(e.run_directory))")

file_sha(path)=bytes2hex(open(SHA.sha256,path))
"""One absolute exporter path, its SHA256 and the expected upstream commit.

Construct with `BackendConfig(path; expected_sha256=nothing, commit=...)`.
The executable is checked when configured and again immediately before launch.
"""
struct BackendConfig
    executable::String
    executable_sha256::String
    commit::String
end
function BackendConfig(path::AbstractString;expected_sha256=nothing,commit=BACKEND_COMMIT)
    isabspath(path) || throw(BackendError(:invalid_executable,"configure one absolute executable path"))
    isfile(path) && !isnothing(Sys.which(path)) || throw(BackendError(:missing_executable,"missing or nonexecutable backend: $path"))
    path=realpath(path);actual=file_sha(path)
    isnothing(expected_sha256) || actual==expected_sha256 || throw(BackendError(:incompatible_backend,"executable hash differs from its configured build"))
    BackendConfig(path,actual,commit)
end

include("BuildPaths.jl")
include("Configuration.jl")
include("Requests.jl")

function atomic_json(path,data)
    mkpath(dirname(path));temporary,io=mktemp(dirname(path);cleanup=false)
    try
        JSON3.pretty(io,data);println(io);flush(io);close(io)
        Base.Filesystem.rename(temporary,path)
    catch
        isopen(io) && close(io)
        isfile(temporary) && rm(temporary)
        rethrow()
    end
    path
end

function child_error(stderr)
    allowed=Set(["unsupported_arithmetic","unsupported_operation","malformed_input","unwritable_output","backend_failure"])
    for line in reverse(split(stderr,'\n'))
        startswith(line,"AV_ERROR ") || continue
        try
            data=JSON3.read(line[10:end],Dict{String,Any})
            if data["schema"]=="av_error_v1" && data["code"] in allowed
                return Symbol(data["code"]),string(data["message"])
            end
        catch
        end
    end
    :child_exit,"backend exited without a valid structured error record"
end

function resident_bytes(pid,ps)
    text=read(pipeline(ignorestatus(`$ps -o rss= -p $pid`);stderr=devnull),String)
    rss=tryparse(Int,strip(text))
    isnothing(rss) ? nothing : 1024rss
end

function stop_backend(process)
    process_running(process) || return
    kill(process,Base.SIGTERM)
    for _ in 1:20
        process_exited(process) && return
        sleep(.01)
    end
    process_running(process) && kill(process,Base.SIGKILL)
end

"""Run an executable with private files, an outer deadline and bounded memory.

Call `run_exporter(input_text, config=default_backend(); ...)` with a namelist.
Return `(data, raw, run_directory, process_info)` after checking the request
token, schema, completion marker and upstream commit. Mathematical validation
is the caller's responsibility. Diagnostic files are retained on failure.

The default memory policy is a hard address-space limit on Linux and a sampled
resident-memory watchdog on macOS. The resident policy can also be selected on
Linux, including for ASan executables whose virtual shadow memory is large.
"""
function run_exporter(input_text::AbstractString,B::BackendConfig=default_backend();
                      work_dir=joinpath(tempdir(),"perfect_forms"),timeout=60.0,
                      output_path=nothing,memory_limit=10*1024^3,
                      memory_policy=:auto)
    isfinite(timeout) && timeout>0 || throw(ArgumentError("positive finite timeout required"))
    memory_limit isa Integer && 0<memory_limit<=typemax(Int) || throw(ArgumentError("positive memory limit in bytes required"))
    memory_policy in (:auto,:address_space,:resident) || throw(ArgumentError("memory policy must be :auto, :address_space or :resident"))
    work_dir=abspath(work_dir)
    try mkpath(work_dir) catch err
        throw(BackendError(:unwritable_output,sprint(showerror,err)))
    end
    folder=mktempdir(work_dir;prefix="request ",cleanup=false)
    input=joinpath(folder,"input.nml");write(input,input_text)
    token=bytes2hex(sha256(input_text*string(time_ns(),getpid())))
    output=isnothing(output_path) ? joinpath(folder,"output.json") : abspath(output_path)
    stdout_path=joinpath(folder,"stdout.log");stderr_path=joinpath(folder,"stderr.log")
    report=Dict{String,Any}("status"=>"prepared","completed"=>false,"request_token"=>token,
        "input_sha256"=>file_sha(input),"backend_commit"=>B.commit,"executable"=>B.executable,
        "executable_sha256"=>B.executable_sha256,"timeout_seconds"=>timeout,"memory_limit_bytes"=>memory_limit,
        "output"=>output,"started_utc"=>string(now(UTC)))
    report_path=joinpath(folder,"process.json")
    function fail(kind,message)
        report["status"]=string(kind);report["error"]=message
        atomic_json(report_path,report)
        throw(BackendError(kind,message,folder))
    end
    isfile(B.executable) || fail(:missing_executable,"configured executable disappeared")
    file_sha(B.executable)==B.executable_sha256 || fail(:incompatible_backend,"configured executable changed")
    ispath(output) && fail(:stale_output,"output path already exists before child launch")
    try
        probe,probe_io=mktemp(dirname(output);cleanup=false);close(probe_io);rm(probe)
    catch err
        fail(:unwritable_output,sprint(showerror,err))
    end
    Sys.islinux() || Sys.isapple() || fail(:unsupported_platform,"backend process control supports Linux and macOS")
    policy=memory_policy==:auto ? (Sys.islinux() ? :address_space : :resident) : memory_policy
    argv=[B.executable,input,output,token]
    ps=nothing
    if policy==:address_space
        Sys.islinux() || fail(:unsupported_platform,"address-space limiting requires Linux; use :resident on macOS")
        limiter=Sys.which("prlimit")
        isnothing(limiter) && fail(:unsupported_platform,"install util-linux for prlimit, or use memory_policy=:resident")
        argv=[limiter,"--as=$memory_limit","--",argv...]
    else
        ps=Sys.which("ps")
        isnothing(ps) && fail(:unsupported_platform,"resident-memory monitoring requires ps")
    end
    report["memory_policy"]=string(policy)
    report["maximum_sampled_rss_bytes"]=0
    report["argv"]=argv;atomic_json(report_path,report)
    started=time_ns();failure=nothing;code=0;signal=0
    try
        open(stdout_path,"w") do stdout_io
            open(stderr_path,"w") do stderr_io
                process=run(pipeline(Cmd(Cmd(argv);dir=folder);stdout=stdout_io,stderr=stderr_io);wait=false)
                try
                    while process_running(process)
                        if (time_ns()-started)/1e9>timeout
                            failure=(:timeout,"outer deadline terminated the backend; no completion checkpoint published")
                            break
                        end
                        if !isnothing(ps)
                            rss=resident_bytes(getpid(process),ps)
                            if isnothing(rss)
                                process_running(process) || break
                                failure=(:memory_monitor_error,"could not read backend resident memory; backend stopped")
                                break
                            end
                            report["maximum_sampled_rss_bytes"]=max(report["maximum_sampled_rss_bytes"],rss)
                            if rss>memory_limit
                                failure=(:memory_limit,"resident-memory watchdog terminated the backend; no completion checkpoint published")
                                break
                            end
                        end
                        sleep(min(.02,timeout/10))
                    end
                finally
                    stop_backend(process)
                    wait(process)
                end
                code=process.exitcode;signal=process.termsignal
            end
        end
    catch err
        err isa BackendError && rethrow()
        fail(:launch_error,sprint(showerror,err))
    end
    report["elapsed_seconds"]=(time_ns()-started)/1e9
    report["exitcode"]=code;report["termination_signal"]=signal
    isnothing(failure) || fail(failure...)
    signal!=0 && fail(:terminated,"backend terminated by signal $signal")
    if code!=0
        kind,message=child_error(read(stderr_path,String));fail(kind,message)
    end
    isfile(output) || fail(:missing_output,"successful child exit without the requested output")
    raw=read(output,String)
    data=try JSON3.read(raw,Dict{String,Any}) catch err
        fail(:truncated_output,sprint(showerror,err))
    end
    get(data,"request_token",nothing)==token || fail(:stale_output,"fresh output has the wrong request token")
    get(data,"schema",nothing)=="av_polyhedral_export_v1" || fail(:incompatible_schema,"unsupported exporter schema")
    get(data,"completed",false)===true || fail(:incomplete_output,"backend did not declare completed enumeration")
    get(data,"backend_commit",nothing)==B.commit || fail(:incompatible_backend,"exported backend version does not match configuration")
    report["status"]="exported_pending_validation";report["raw_output_sha256"]=bytes2hex(sha256(raw))
    atomic_json(report_path,report)
    (;data,raw,run_directory=folder,process_info=report)
end

end
