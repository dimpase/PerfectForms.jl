using PerfectForms, JSON3, Test

const CONTRACT_ROOT=mktempdir(;prefix="perfect forms contracts ",cleanup=false)
const OBSERVED=Dict{String,Any}()

include("contracts.jl")

@testset "standalone enumeration" begin
    B=default_backend()
    pins=JSON3.read(read(joinpath(pkgdir(PerfectForms),"backend","pins.json"),String))
    @test B.commit==pins["commit"]
    info=backend_build_info(B)
    @test info["executable_sha256"]==B.executable_sha256
    @test info["nauty_provider"]=="SYSTEM"
    @test !isempty(info["nauty_library"])
    for (D,count) in ((1,1),(5,2),(8,2),(12,3),(13,9),(40,52))
        result=enumerate_perfect_forms(D;config=B,work_dir=CONTRACT_ROOT,timeout=180.)
        @test result.data["completed"]===true
        @test isempty(result.data["pending_facets"])
        @test length(result.data["representatives"])==count
        @test result.process_info["status"]=="exported_pending_validation"
        @test isfile(joinpath(result.run_directory,"process.json"))
    end
    @test_throws ArgumentError perfect_form_request(9)
    @test_throws ArgumentError perfect_form_request(5;arithmetic="gmp\"\n/")
    # Loading and running this interface must not pull in the arithmetic stack.
    @test all(id.name ∉ ("Oscar","Hecke","GAP") for id in keys(Base.loaded_modules))
end

@testset "installation selection and build provenance" begin
    B=default_backend()
    selected=joinpath(CONTRACT_ROOT,"config.json")
    data=Dict{String,Any}("schema"=>"av_backend_config_v1","executable"=>B.executable,
        "executable_sha256"=>B.executable_sha256,"commit"=>B.commit)
    PerfectForms.atomic_json(selected,data)
    withenv("PERFECT_FORMS_BACKEND_CONFIG"=>selected) do
        @test default_backend().executable==B.executable
    end
    @test default_backend(;config_path=selected).executable_sha256==B.executable_sha256
    for mutation in (d->(d["schema"]="wrong"),d->delete!(d,"commit"),d->(d["executable"]=false))
        bad=deepcopy(data);mutation(bad);PerfectForms.atomic_json(selected,bad)
        expect_backend_error("malformed configuration",:invalid_configuration) do
            default_backend(;config_path=selected)
        end
    end
    write(selected,"{")
    expect_backend_error("truncated configuration",:invalid_configuration) do
        default_backend(;config_path=selected)
    end
    expect_backend_error("relative configuration",:invalid_configuration) do
        default_backend(;config_path="config.json")
    end
    info=backend_build_info(B);info["executable_sha256"]="0"^64
    PerfectForms.atomic_json(selected,info)
    expect_backend_error("mismatched provenance",:incompatible_backend) do
        backend_build_info(B;path=selected)
    end
end

@testset "fresh output and identity checks" begin
    request=perfect_form_request(5)
    for (name,fields,kind) in (
        ("schema",Dict("schema"=>"unsupported"),:incompatible_schema),
        ("backend",Dict("backend_commit"=>"wrong"),:incompatible_backend))
        payload=Dict("schema"=>"av_polyhedral_export_v1","completed"=>true,
            "backend_commit"=>PerfectForms.BACKEND_COMMIT)
        merge!(payload,fields)
        body="d=json.loads("*repr(JSON3.write(payload))*")\nd['request_token']=sys.argv[3]\njson.dump(d,open(sys.argv[2],'w'))"
        expect_backend_error(name,kind) do
            run_exporter(request,fake_backend(name,body);work_dir=CONTRACT_ROOT)
        end
    end
    output=joinpath(CONTRACT_ROOT,"old output.json");write(output,"old result")
    expect_backend_error("pre-existing output",:stale_output) do
        run_exporter(request,default_backend();work_dir=CONTRACT_ROOT,output_path=output)
    end
    @test read(output,String)=="old result"
    replaced=fake_backend("replaced","pass")
    write(replaced.executable,"#!/bin/sh\nexit 0\n")
    expect_backend_error("executable replaced after configuration",:incompatible_backend) do
        run_exporter(request,replaced;work_dir=CONTRACT_ROOT)
    end
    spaced=joinpath(CONTRACT_ROOT,"path with spaces");mkpath(spaced)
    B=default_backend();copy=joinpath(spaced,"perfect forms exporter")
    cp(B.executable,copy);chmod(copy,0o700)
    run=run_exporter(request,BackendConfig(copy);work_dir=CONTRACT_ROOT)
    @test run.data["completed"]===true
end

println("PerfectForms test diagnostics: ",CONTRACT_ROOT)
