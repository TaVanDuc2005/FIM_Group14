# So sánh với kết quả tham chiếu của SPMF (test/data/spmf/*.txt).
# File tham chiếu được sinh bởi: julia --project scripts/spmf_reference.jl
# Case nào chưa có file tham chiếu sẽ bị đánh dấu "Broken"/skip chứ không âm thầm pass.
# Cần spmf_cases.jl đã được include (runtests.jl làm việc này).

@testset "SPMF reference" begin
    rows = String[]
    for (name, input, minsup_str) in SPMF_CASES
        ref_path = spmf_reference_path(name)
        @testset "$name" begin
            if !isfile(ref_path)
                @warn "Thiếu file tham chiếu SPMF $ref_path; chạy scripts/spmf_reference.jl"
                @test_skip false
            else
                reference = read_itemsets(ref_path)
                tx = read_transactions(input)
                minsup = parse_minsup(minsup_str)
                for (label, algo) in (("basic", apriori), ("bitarray", apriori_bitarray))
                    cmp = compare_itemsets(algo(tx, minsup), reference)
                    @test cmp.exact
                    push!(rows, string(rpad(name, 18), rpad(minsup_str, 8), rpad(label, 10),
                                       lpad(cmp.n_reference, 7), lpad(cmp.matched, 9), "   ",
                                       round(100 * cmp.match_rate; digits = 2), "%"))
                end
            end
        end
    end
    if !isempty(rows)
        println("\nTỉ lệ khớp với SPMF")
        println(rpad("case", 18), rpad("minsup", 8), rpad("algo", 10), lpad("spmf", 7), lpad("matched", 9), "   rate")
        foreach(println, rows)
    end
end
