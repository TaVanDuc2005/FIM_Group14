module AprioriFIM

include("io.jl")
include("apriori.jl")
include("apriori_bitarray.jl")

export read_transactions, write_itemsets, read_itemsets,
       min_support_count, parse_minsup, compare_itemsets,
       apriori, apriori_bitarray

end # module
