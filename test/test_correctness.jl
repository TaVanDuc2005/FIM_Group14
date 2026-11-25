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

@testset "minsup semantics (giống SPMF)" begin
    @test min_support_count(1.0, 4) == 4        # 100%, không phải 1 giao dịch
    @test min_support_count(1, 4) == 1          # số nguyên = số đếm tuyệt đối
    @test min_support_count(0.0, 4) == 1        # tối thiểu 1 giao dịch
    # Float64: 0.07*3000 = 210.00000000000003 -> ceil = 211, cùng phép tính với SPMF (Java double).
    # Case "quest_medium_7" trong test_spmf.jl kiểm chứng điều này với output thật của SPMF.
    @test min_support_count(0.07, 3000) == 211
    @test min_support_count(parse_minsup("7%"), 3000) == 211
    @test_throws ArgumentError min_support_count(1.5, 4)
    @test_throws ArgumentError min_support_count(-1, 4)

    @test parse_minsup("40%") == 0.4
    @test parse_minsup("0.4") == 0.4
    @test parse_minsup("1.0") === 1.0
    @test parse_minsup("2") === 2
end

@testset "SPMF output I/O" begin
    path = tempname()
    write_itemsets(path, TOY_EXPECTED)
    @test read_itemsets(path) == TOY_EXPECTED

    # SPMF có thể ghi itemset theo thứ tự bất kỳ, có dòng trống.
    write(path, "5 2 #SUP: 3\n\n1 #SUP: 2\n")
    @test read_itemsets(path) == Dict([2, 5] => 3, [1] => 2)

    # Dòng metadata của SPMF bản mới bị bỏ qua; file chỉ có metadata = không có itemset.
    write(path, "@FILETYPE=\"Frequent itemsets\"\n@SOURCE=\"SPMF\"\n3 1 #SUP: 4\n")
    @test read_itemsets(path) == Dict([1, 3] => 4)
    write(path, "@FILETYPE=\"Frequent itemsets\"\n")
    @test isempty(read_itemsets(path))
    write(path, "1 2 3\n")
    @test_throws ErrorException read_itemsets(path)

    cmp = compare_itemsets(TOY_EXPECTED, TOY_EXPECTED)
    @test cmp.exact && cmp.match_rate == 1.0
    @test compare_itemsets(Dict{Vector{Int},Int}(), Dict{Vector{Int},Int}()).exact

    ours = copy(TOY_EXPECTED)
    delete!(ours, [2, 3, 5])        # thiếu 1
    ours[[1, 3]] = 99               # sai support 1
    ours[[4]] = 1                   # thừa 1
    cmp = compare_itemsets(ours, TOY_EXPECTED)
    @test !cmp.exact
    @test cmp.missing == [[2, 3, 5]]
    @test cmp.extra == [[4]]
    @test cmp.wrong_support == [([1, 3], 99, 2)]
    @test cmp.matched == 7 && cmp.match_rate == 7 / 10
end

@testset "bitarray: chỉ tạo tidset cho item phổ biến" begin
    tx = [[1, 2], [2, 3], [2, 4]]
    @test sort!(collect(keys(AprioriFIM.build_tidsets(tx, [2])))) == [2]
    @test AprioriFIM.count_items([[1, 1, 2], [1]]) == Dict(1 => 2, 2 => 1)
    a, b = trues(130), falses(130)
    b[1:2:end] .= true
    dest = falses(130)
    @test AprioriFIM.and_count!(dest, a, b) == 65 && dest == b
end

@testset "candidate generation and support" begin
    # Agrawal and Srikant, Figure 3: L2 generates C3 = { {2, 3, 5} }.
    prev = [[1, 3], [2, 3], [2, 5], [3, 5]]
    @test AprioriFIM.generate_candidates(prev) == [[2, 3, 5]]

    # Agrawal and Srikant, Section 2.1.1: join yields {1,2,3,4} and
    # {1,3,4,5}; pruning removes the latter because {1,4,5} is absent.
    prev = [[1, 2, 3], [1, 2, 4], [1, 3, 4], [1, 3, 5], [2, 3, 4]]
    @test AprioriFIM.generate_candidates(prev) == [[1, 2, 3, 4]]

    # Trường generators (mục 2.2.2): {1 2 3 4} được join từ prev[1] = {1 2 3} và prev[2] = {1 2 4}.
    candidates, parents = AprioriFIM.generate_candidates_with_parents(prev)
    @test candidates == [[1, 2, 3, 4]] && parents == [(1, 2)]
    @test AprioriFIM.generate_candidates_with_parents(Vector{Vector{Int}}()) == ([], [])

    # Ứng viên sinh ra theo thứ tự từ điển (bản bitarray dựa vào tính chất này),
    # và mỗi cặp cha hợp lại đúng bằng ứng viên.
    L2 = [[a, b] for a in 1:6 for b in (a + 1):6 if (a + b) % 4 != 0]
    candidates, parents = AprioriFIM.generate_candidates_with_parents(L2)
    @test issorted(candidates)
    @test all(sort!(union(L2[i], L2[j])) == c for (c, (i, j)) in zip(candidates, parents))

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

# So sánh với SPMF trên nhiều CSDL: xem test_spmf.jl.

@testset "maxlen giới hạn kích thước tập" begin
    for (name, minsup) in (("dense_small", 0.3), ("long_tx", 0.6), ("quest_medium", 0.02))
        tx = read_transactions(joinpath(@__DIR__, "data", "db", name * ".txt"))
        full = apriori_bitarray(tx, minsup)
        for maxlen in (1, 2, 3, 100)
            expected = filter(p -> length(p.first) <= maxlen, full)
            @test apriori(tx, minsup; maxlen) == expected
            @test apriori_bitarray(tx, minsup; maxlen) == expected
        end
    end
    @test_throws ArgumentError apriori([[1, 2]], 1; maxlen = 0)
    @test_throws ArgumentError apriori_bitarray([[1, 2]], 1; maxlen = 0)
end
