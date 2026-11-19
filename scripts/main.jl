# Cách chạy:
#   julia --project scripts/main.jl <input.txt> <minsup> <output.txt> [basic|bitarray]
using AprioriFIM

function main(args)
    if length(args) < 3
        println("Usage: main.jl <input> <minsup> <output> [basic|bitarray]")
        return 1
    end
    input, minsup, output = args[1], parse(Float64, args[2]), args[3]
    mode = length(args) >= 4 ? args[4] : "bitarray"
    tx = read_transactions(input)
    algo = mode == "basic" ? apriori : apriori_bitarray
    t = @elapsed res = algo(tx, minsup)
    write_itemsets(output, res)
    println("Found $(length(res)) frequent itemsets in $(round(t; digits=3)) s")
    return 0
end

exit(main(ARGS))
