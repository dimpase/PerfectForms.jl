function expect_backend_error(f,label,kind)
    observed=nothing
    try f() catch err;observed=err;end
    @test observed isa BackendError
    if observed isa BackendError
        @test observed.kind==kind
        OBSERVED[label]=Dict("kind"=>string(observed.kind),"expected"=>string(kind),
            "message"=>observed.message,"diagnostics"=>observed.run_directory)
    else
        OBSERVED[label]=Dict("unexpected"=>string(observed))
    end
end

function fake_backend(name,body)
    path=joinpath(CONTRACT_ROOT,"fake_backend_"*name*".py")
    python=Sys.which("python3")
    isnothing(python) && error("contract tests require python3")
    write(path,"#!$python\nimport sys,json,time,os,signal\n"*body*"\n")
    chmod(path,0o700)
    BackendConfig(path)
end

@testset "executable and protocol contracts" begin
    B=default_backend();request=perfect_form_request(5)
    expect_backend_error("missing executable",:missing_executable) do
        BackendConfig(joinpath(CONTRACT_ROOT,"missing executable"))
    end
    expect_backend_error("relative executable",:invalid_executable) do
        BackendConfig("AV_ExportPerfectOrbits")
    end
    expect_backend_error("malformed input",:malformed_input) do
        run_exporter("&UNKNOWN_BLOCK\n bad=1\n/\n",B;work_dir=CONTRACT_ROOT)
    end
    expect_backend_error("unsupported arithmetic",:unsupported_arithmetic) do
        run_exporter(perfect_form_request(5;arithmetic="flint"),B;work_dir=CONTRACT_ROOT)
    end
    expect_backend_error("unsupported complex request",:unsupported_operation) do
        run_exporter(replace(request,"ComputeBoundary = F"=>"ComputeBoundary = T"),B;work_dir=CONTRACT_ROOT)
    end
    expect_backend_error("unwritable output",:unwritable_output) do
        blocked=joinpath(CONTRACT_ROOT,"not a directory");write(blocked,"file")
        run_exporter(request,B;work_dir=CONTRACT_ROOT,output_path=joinpath(blocked,"output.json"))
    end
    @test_throws ArgumentError run_exporter(request,B;memory_limit=0)
    @test_throws ArgumentError run_exporter(request,B;memory_policy=:invalid)
    @test PerfectForms.resident_bytes(getpid(),Sys.which("ps"))>0
    resident=run_exporter(request,B;work_dir=CONTRACT_ROOT,memory_policy=:resident)
    @test resident.process_info["memory_policy"]=="resident"
    @test resident.data["completed"]===true
    expect_backend_error("resident memory ceiling",:memory_limit) do
        bad=fake_backend("resident","payload=bytearray(32*1024*1024)\ntime.sleep(10)")
        run_exporter(request,bad;work_dir=CONTRACT_ROOT,memory_policy=:resident,memory_limit=16*1024^2)
    end
    expect_backend_error("resident watchdog deadline",:timeout) do
        bad=fake_backend("resident_timeout","time.sleep(10)")
        run_exporter(request,bad;work_dir=CONTRACT_ROOT,memory_policy=:resident,timeout=.1)
    end
    expect_backend_error("nonzero exit",:child_exit) do
        bad=fake_backend("exit7","print('deliberate nonzero child exit',file=sys.stderr)\nsys.exit(7)")
        run_exporter(request,bad;work_dir=CONTRACT_ROOT)
    end
    expect_backend_error("signal termination",:terminated) do
        bad=fake_backend("signal","os.kill(os.getpid(),signal.SIGTERM)")
        run_exporter(request,bad;work_dir=CONTRACT_ROOT)
    end
    expect_backend_error("missing output",:missing_output) do
        run_exporter(request,fake_backend("nooutput","pass");work_dir=CONTRACT_ROOT)
    end
    expect_backend_error("truncated output",:truncated_output) do
        run_exporter(request,fake_backend("truncated","open(sys.argv[2],'w').write('{\"schema\":')");work_dir=CONTRACT_ROOT)
    end
    expect_backend_error("stale token",:stale_output) do
        bad=fake_backend("staletoken","json.dump({'request_token':'wrong'},open(sys.argv[2],'w'))")
        run_exporter(request,bad;work_dir=CONTRACT_ROOT)
    end
    expect_backend_error("incomplete output",:incomplete_output) do
        bad=fake_backend("incomplete","json.dump({'request_token':sys.argv[3],'schema':'av_polyhedral_export_v1','completed':False},open(sys.argv[2],'w'))")
        run_exporter(request,bad;work_dir=CONTRACT_ROOT)
    end
    expect_backend_error("changed executable rejected",:incompatible_backend) do
        BackendConfig(B.executable;expected_sha256="0"^64)
    end
end
