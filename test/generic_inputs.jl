@testset "generic upstream input" begin
    # These are construction checks, not an enumeration of larger cases.
    @test occursin("RealImagProd = -16",perfect_form_request(65))
    @test occursin("RealImagDim = 3",perfect_form_request(-4;dimension=3))
    @test occursin("ClassicDim = 5",perfect_form_request(1;dimension=5))
    @test occursin("RealImagProd = 3",perfect_form_request(-12)) # nonmaximal order
    @test occursin("TypeTspace = \"Classic\"",perfect_form_request())
    for invalid in (0,4,6,9,-1)
        @test_throws ArgumentError perfect_form_request(invalid)
    end
    @test_throws ArgumentError perfect_form_request(5;dimension=0)

    # Unknown but syntactically valid options/types reach upstream unchanged.
    request=perfect_form_request(;tspace=Dict("TypeTspace"=>"future_type","FutureOption"=>23))
    @test occursin("FutureOption = 23",request)
    expect_backend_error("upstream rejects unknown T-space",:malformed_input) do
        enumerate_perfect_forms(request;work_dir=CONTRACT_ROOT)
    end
    expect_backend_error("uncompiled arithmetic reaches backend",:unsupported_arithmetic) do
        enumerate_perfect_forms(1;arithmetic="another_arithmetic",work_dir=CONTRACT_ROOT)
    end
    @test_throws ArgumentError perfect_form_request(;tspace=Dict("TypeTspace\n&DATA"=>"Classic"))
    @test_throws ArgumentError perfect_form_request(;tspace=(TypeTspace="Classic!comment",))
    @test_throws ArgumentError perfect_form_request(;data=(SomeNumber=Inf,))

    # Both public generic entry points must reach the native executable.
    raw=enumerate_perfect_forms(perfect_form_request(1;dimension=3);work_dir=CONTRACT_ROOT)
    @test raw.data["lattice_dimension"]==3
    @test length(raw.data["representatives"])==1
    # Upstream's full-complex CLI now defaults ComputeComplex to T. Our
    # forms-only endpoint still accepts requests that omit that flag.
    minimal=enumerate_perfect_forms("&TSPACE\n TypeTspace = \"Classic\"\n ClassicDim = 3\n/\n";
        work_dir=CONTRACT_ROOT)
    @test minimal.data["lattice_dimension"]==3
    @test length(minimal.data["representatives"])==1
    configured=enumerate_perfect_forms(;tspace=(TypeTspace="ImagQuad",RealImagDim=2,
        RealImagSum=0,RealImagProd=1,ListComm="Use_realimag"),work_dir=CONTRACT_ROOT)
    @test configured.data["form_space_dimension"]==4
    @test length(configured.data["representatives"])==1

    # File-defined spaces exercise input beyond the built-in number fields.
    # This basis spans all symmetric binary forms; it must reproduce A2.
    basis=joinpath(CONTRACT_ROOT,"raw basis with spaces.txt")
    write(basis,"3\n2 2\n1 0\n0 0\n2 2\n0 1\n1 0\n2 2\n0 0\n0 1\n")
    raw_space=enumerate_perfect_forms(;tspace=Dict("TypeTspace"=>"Raw",
        "FileListMat"=>basis,"SuperMatMethod"=>"Compute"),work_dir=CONTRACT_ROOT)
    @test raw_space.data["lattice_dimension"]==2
    @test raw_space.data["form_space_dimension"]==3
    @test length(raw_space.data["representatives"])==1
    @test only(raw_space.data["representatives"])["stabilizer_order"]=="12"
end
