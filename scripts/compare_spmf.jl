# So sánh kết quả của nhóm với SPMF trên một CSDL bất kỳ (kể cả các tập benchmark lớn).
#   julia --project scripts/compare_spmf.jl <input.txt> <minsup> [--spmf=out.txt] [--algo=basic|bitarray|both]
# - minsup theo cú pháp SPMF, ví dụ "80%".
# - Không có --spmf: script tự chạy SPMF (cần Java + tools/spmf/spmf.jar).
# - --algo mặc định "both"; trên tập lớn nên dùng --algo=bitarray vì bản basic rất chậm.
# Ví dụ:
#   julia --project scripts/compare_spmf.jl data/raw/chess.txt 80%
#   julia --project scripts/compare_spmf.jl data/raw/retail.txt 1% --algo=bitarray
using AprioriFIM
include("spmf_common.jl")

const ALGORITHMS = Dict("basic" => [("basic", apriori)],
                        "bitarray" => [("bitarray", apriori_bitarray)],
                        "both" => [("basic", apriori), ("bitarray", apriori_bitarray)])

function main(args)
    positional = filter(a -> !startswith(a, "--"), args)
    options = Dict(split(a[3:end], "="; limit = 2) |> p -> (p[1] => get(p, 2, ""))
                   for a in args if startswith(a, "--"))
    algo_key = get(options, "algo", "both")
    if length(positional) < 2 || !haskey(ALGORITHMS, algo_key)
        println("Usage: compare_spmf.jl <input> <minsup> [--spmf=out.txt] [--algo=basic|bitarray|both]")
        return 1
    end
    input, minsup_str = positional[1], positional[2]

    spmf_output = get(options, "spmf", "")
    if isempty(spmf_output)
        spmf_output = tempname() * "_spmf.txt"
        t = run_spmf(input, spmf_output, minsup_str)
        println("SPMF Apriori: $(round(t; digits = 3)) s (gồm khởi động JVM)")
    end

    reference = read_itemsets(spmf_output)
    tx = read_transactions(input)
    minsup = parse_minsup(minsup_str)
    println("$input: $(length(tx)) giao dịch, minsup = $minsup_str -> $(min_support_count(minsup, length(tx))) giao dịch")

    all_exact = true
    for (label, algo) in ALGORITHMS[algo_key]
        t = @elapsed ours = algo(tx, minsup)
        cmp = compare_itemsets(ours, reference)
        print_comparison(stdout, label, cmp)
        println("    thời gian: $(round(t; digits = 3)) s")
        all_exact &= cmp.exact
    end
    return all_exact ? 0 : 2
end

exit(main(ARGS))
