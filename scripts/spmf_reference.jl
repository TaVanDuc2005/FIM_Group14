# Sinh file kết quả tham chiếu SPMF cho mọi case trong test/spmf_cases.jl.
#   julia --project scripts/spmf_reference.jl
# Kết quả ghi vào test/data/spmf/<case>.txt; commit các file này để
# `julia --project test/runtests.jl` so sánh được mà không cần Java.
using AprioriFIM: read_itemsets, read_rules
include("spmf_common.jl")
include(joinpath(@__DIR__, "..", "test", "spmf_cases.jl"))

for (name, input, minsup) in SPMF_CASES
    output = spmf_reference_path(name)
    t = run_spmf(input, output, minsup)
    n = length(read_itemsets(output))  # bỏ qua dòng metadata @FILETYPE/@SOURCE
    println(rpad(name, 18), " minsup = ", rpad(minsup, 6), " -> ", lpad(n, 6), " itemsets  (", round(t; digits = 2), " s)")
end

for (name, input, minsup, minconf) in SPMF_RULE_CASES
    output = spmf_reference_path(name)
    t = run_spmf(input, output, minsup, minconf, "0"; algorithm = "FPGrowth_association_rules_with_lift")
    n = length(read_rules(output))
    println(rpad(name, 26), " minsup = ", rpad(minsup, 6), " minconf = ", rpad(minconf, 6), " -> ",
            lpad(n, 7), " rules  (", round(t; digits = 2), " s)")
end
