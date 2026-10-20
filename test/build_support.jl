using Scratch

@testset "automatic backend selection" begin
    B=default_backend()
    scratch=mktempdir(CONTRACT_ROOT;prefix="scratch ")
    withenv("PERFECT_FORMS_BACKEND_CONFIG"=>nothing) do
        Scratch.with_scratch_directory(scratch) do
            @test PerfectForms.default_config_path()==joinpath(PerfectForms.PACKAGE_ROOT,"backend","config.json")
            withenv("PERFECT_FORMS_BACKEND_CONFIG"=>"") do
                @test PerfectForms.default_config_path()==joinpath(PerfectForms.PACKAGE_ROOT,"backend","config.json")
            end
            config=joinpath(scratch,"installed config.json")
            PerfectForms.atomic_json(config,Dict(
                "schema"=>"av_backend_config_v1","executable"=>B.executable,
                "executable_sha256"=>B.executable_sha256,"commit"=>B.commit))
            selection=PerfectForms.BuildPaths.selection_file(PerfectForms.PACKAGE_ROOT)
            PerfectForms.atomic_json(selection,Dict(
                "schema"=>"perfect_forms_build_selection_v1","config_path"=>config))
            @test default_backend().executable==B.executable
            withenv("PERFECT_FORMS_BACKEND_CONFIG"=>"") do
                @test default_backend().executable==B.executable
                @test_throws BackendError default_backend(config_path="")
            end
            withenv("PERFECT_FORMS_BACKEND_CONFIG"=>"/missing/config.json") do
                @test PerfectForms.default_config_path()=="/missing/config.json"
                @test default_backend(config_path=config).executable==B.executable
            end
            write(selection,"{")
            @test_throws BackendError default_backend()
            @test default_backend(config_path=config).executable==B.executable
        end
    end
    # Two working checkouts must not select or overwrite one another's builds.
    roots=[mktempdir(CONTRACT_ROOT) for _ in 1:2]
    for root in roots
        mkpath(joinpath(root,"backend"))
        cp(joinpath(PerfectForms.PACKAGE_ROOT,"backend","pins.json"),joinpath(root,"backend","pins.json"))
    end
    @test PerfectForms.BuildPaths.state_directory(roots[1])!=PerfectForms.BuildPaths.state_directory(roots[2])
end

@testset "local C++ source provenance" begin
    fixture=mktempdir(CONTRACT_ROOT;prefix="cmake source ")
    source=joinpath(fixture,"upstream");mkpath(source)
    git=Sys.which("git")
    cmake=Sys.which("cmake")
    @test !isnothing(git) && !isnothing(cmake)
    run(pipeline(`$git -C $source init -q`;stdout=devnull,stderr=devnull))
    header=joinpath(source,"example.h")
    write(header,"constexpr int value = 1;\n")
    run(`$git -C $source add example.h`)
    run(`$git -C $source -c user.name=Test -c user.email=test@localhost -c commit.gpgsign=false commit -qm initial`)
    commit=strip(read(`$git -C $source rev-parse HEAD`,String))
    helper=replace(joinpath(PerfectForms.PACKAGE_ROOT,"cmake","SourceProvenance.cmake"),'\\'=>'/')
    write(joinpath(fixture,"CMakeLists.txt"),"""
    cmake_minimum_required(VERSION 3.24)
    project(ProvenanceTest NONE)
    find_package(Git REQUIRED)
    include("$helper")
    av_describe_source("\${SOURCE}" "\${EXPECTED}" info)
    file(WRITE "\${CMAKE_BINARY_DIR}/source.json" "\${info}\\n")
    """)
    build=joinpath(fixture,"build")
    function configure(development;expected=commit,dir=source)
        cmd=`$cmake -S $fixture -B $build -DSOURCE=$dir -DEXPECTED=$expected -DAV_BACKEND_DEVELOPMENT=$development`
        log=IOBuffer()
        ok=success(pipeline(cmd;stdout=log,stderr=log))
        text=String(take!(log))
        info=ok ? JSON3.read(read(joinpath(build,"source.json"),String)) : nothing
        (;ok,text,info)
    end
    clean=configure("OFF")
    @test clean.ok
    @test !clean.info["dirty"]
    write(header,"constexpr int value = 2;\n")
    @test !configure("OFF").ok
    patched=configure("ON")
    @test patched.ok && patched.info["dirty"]
    @test patched.info["tree_sha256"]!=clean.info["tree_sha256"]
    @test read(header,String)=="constexpr int value = 2;\n"
    write(joinpath(source,"new header.h"),"constexpr int extra = 3;\n")
    added=configure("ON")
    @test added.ok
    @test added.info["tree_sha256"]!=patched.info["tree_sha256"]
    @test configure("ON";expected="0"^40).ok
    @test !configure("OFF";expected="0"^40).ok
    empty_submodule=joinpath(source,"missing submodule");mkpath(empty_submodule)
    @test !configure("ON";dir=empty_submodule).ok
end
