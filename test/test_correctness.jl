const TOY = joinpath(@__DIR__, "..", "data", "toy", "toy1.txt")

# Kết quả tính tay: minsup = 2 giao dịch trên toy1.txt
const TOY_EXPECTED = Dict{Vector{Int},Int}(
    [1] => 2, [2] => 3, [3] => 3, [5] => 3,
    [1, 3] => 2, [2, 3] => 2, [2, 5] => 3, [3, 5] => 2,
    [2, 3, 5] => 2,
)

@testset "I/O" begin
    tx = read_transactions(TOY)
    @test length(tx) == 4
    @test tx[3] == [1, 2, 3, 5]
    @test min_support_count(0.5, 4) == 2
end

@testset "candidate generation and support" begin
    prev = [[1, 3], [2, 3], [2, 5], [3, 5]]
    @test AprioriFIM.generate_candidates(prev) == [[2, 3, 5]]

    transactions = [[1, 2, 2], [2, 3], [1, 2, 3]]
    @test AprioriFIM.count_support([[2], [1, 2], [1, 3]], transactions) ==
          Dict([2] => 3, [1, 2] => 2, [1, 3] => 1)
end

@testset "toy1 - basic" begin
    @test apriori(read_transactions(TOY), 2) == TOY_EXPECTED
end

@testset "toy1 - bitarray" begin
    @test apriori_bitarray(read_transactions(TOY), 2) == TOY_EXPECTED
end

# TODO: thêm >= 5 CSDL (nhỏ, lớn, thưa, dày, 1 giao dịch) và
#       so sánh với file kết quả SPMF đặt trong test/data/.
