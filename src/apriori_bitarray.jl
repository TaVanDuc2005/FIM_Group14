# Bản tối ưu: mỗi item có một tidset dạng BitVector (độ dài = số giao dịch).
# Support của itemset = count(&(tidset của các item)).
# Giữ cùng giao diện với `apriori` để so sánh trực tiếp trong benchmark.

"""
    build_tidsets(transactions) -> Dict{Int,BitVector}
"""
function build_tidsets(transactions::Vector{Vector{Int}})::Dict{Int,BitVector}
    error("TODO: build_tidsets")
end

"""
    apriori_bitarray(transactions, minsup) -> Dict{Vector{Int},Int}
"""
function apriori_bitarray(transactions::Vector{Vector{Int}}, minsup::Real)::Dict{Vector{Int},Int}
    error("TODO: apriori_bitarray")
end
