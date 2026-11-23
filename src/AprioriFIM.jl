module AprioriFIM

include("io.jl")
include("apriori.jl")
include("apriori_bitarray.jl")
include("rules.jl")

export read_transactions, write_itemsets, read_itemsets,
       min_support_count, parse_minsup, compare_itemsets,
       apriori, apriori_bitarray,
       Rule, association_rules, write_rules, read_rules, compare_rules,
       encode_transactions, decode, format_rule, read_labeled_transactions

end # module
