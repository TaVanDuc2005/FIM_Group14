using Test
using AprioriFIM

include("spmf_cases.jl")   # danh sách case SPMF dùng chung cho test_spmf.jl và test_rules.jl

@testset "AprioriFIM" begin
    include("test_correctness.jl")
    include("test_spmf.jl")
    include("test_rules.jl")
    include("test_market_basket.jl")
end
