# Cách chạy:
#   julia --project scripts/main.jl <input.txt> <minsup> <output.txt> [basic|bitarray]
#
# minsup: "40%" hoặc "0.4" = tỉ lệ (giống SPMF, "1.0" = 100%); "2" = số giao dịch tuyệt đối.
# Ví dụ:
#   julia --project scripts/main.jl data/toy/toy1.txt 50% out.txt bitarray
using AprioriFIM

const ALGORITHMS = Dict("basic" => apriori, "bitarray" => apriori_bitarray)

function main(args)
    if length(args) < 3 || (length(args) >= 4 && !haskey(ALGORITHMS, args[4]))
        println("Usage: main.jl <input> <minsup> <output> [basic|bitarray]")
        println("  minsup: 40% | 0.4 (tỉ lệ) | 2 (số giao dịch)")
        return 1
    end
    input, minsup, output = args[1], parse_minsup(args[2]), args[3]
    mode = length(args) >= 4 ? args[4] : "bitarray"
    tx = read_transactions(input)
    algo = ALGORITHMS[mode]
    t = @elapsed res = algo(tx, minsup)
    write_itemsets(output, res)
    println("[$mode] $(length(tx)) transactions, minsup = $(min_support_count(minsup, length(tx))) ",
            "-> $(length(res)) frequent itemsets in $(round(t; digits=3)) s")
    return 0
end

exit(main(ARGS))
