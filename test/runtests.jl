using Test
using AprioriFIM

@testset "AprioriFIM" begin
    include("test_correctness.jl")
    include("test_spmf.jl")
end
