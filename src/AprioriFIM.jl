module AprioriFIM

include("io.jl")
include("apriori.jl")
include("apriori_bitarray.jl")

export read_transactions, write_itemsets,
       min_support_count, apriori, apriori_bitarray

end # module
