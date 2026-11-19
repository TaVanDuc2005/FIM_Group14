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
    # Agrawal and Srikant, Figure 3: L2 generates C3 = { {2, 3, 5} }.
    prev = [[1, 3], [2, 3], [2, 5], [3, 5]]
    @test AprioriFIM.generate_candidates(prev) == [[2, 3, 5]]

    # Agrawal and Srikant, Section 2.1.1: join yields {1,2,3,4} and
    # {1,3,4,5}; pruning removes the latter because {1,4,5} is absent.
    prev = [[1, 2, 3], [1, 2, 4], [1, 3, 4], [1, 3, 5], [2, 3, 4]]
    @test AprioriFIM.generate_candidates(prev) == [[1, 2, 3, 4]]

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

@testset "basic and bitarray agree" begin
    databases = [
        (Vector{Vector{Int}}(), 1),
        ([Int[]], 1),
        ([[1, 2, 2], [2, 3], [1, 2, 3]], 2),
        ([[1, 4], [1, 2, 4], [2, 3], [4]], 0.5),
        ([[1, 2, 3]], 1),
        ([[1, 2], [2], [1]], 4),
    ]

    for (transactions, minsup) in databases
        @test apriori_bitarray(transactions, minsup) == apriori(transactions, minsup)
    end
end

@testset "bitarray edge cases" begin
    @test isempty(apriori_bitarray(Vector{Vector{Int}}(), 1))
    @test apriori_bitarray([[1, 2, 3]], 1) ==
          Dict([1] => 1, [2] => 1, [3] => 1, [1, 2] => 1, [1, 3] => 1,
               [2, 3] => 1, [1, 2, 3] => 1)
    @test isempty(apriori_bitarray([[1, 2], [2], [1]], 4))
end

# TODO: thêm >= 5 CSDL (nhỏ, lớn, thưa, dày, 1 giao dịch) và
#       so sánh với file kết quả SPMF đặt trong test/data/.
