# Bản tối ưu: mỗi item có một tidset dạng BitVector (độ dài = số giao dịch).
# Support của itemset = count(&(tidset của các item)).
# Giữ cùng giao diện với `apriori` để so sánh trực tiếp trong benchmark.

"""
    build_tidsets(transactions) -> Dict{Int,BitVector}
"""
function build_tidsets(transactions::Vector{Vector{Int}})::Dict{Int,BitVector}
    tidsets = Dict{Int,BitVector}()

    for (transaction_index, transaction) in enumerate(transactions)
        for item in transaction
            tidset = get!(tidsets, item) do
                falses(length(transactions))
            end
            tidset[transaction_index] = true
        end
    end

    return tidsets
end

"""
    apriori_bitarray(transactions, minsup) -> Dict{Vector{Int},Int}
"""
function apriori_bitarray(transactions::Vector{Vector{Int}}, minsup::Real)::Dict{Vector{Int},Int}
    minsup_count = min_support_count(minsup, length(transactions))
    tidsets = build_tidsets(transactions)
    result = Dict{Vector{Int},Int}()
    prev = Vector{Vector{Int}}()
    prev_tids = Dict{Vector{Int},BitVector}()

    for item in sort!(collect(keys(tidsets)))
        itemset = [item]
        item_tids = tidsets[item]
        support = count(item_tids)
        if support >= minsup_count
            result[itemset] = support
            push!(prev, itemset)
            prev_tids[itemset] = item_tids
        end
    end

    buffer = falses(length(transactions))
    while !isempty(prev)
        sort!(prev)
        candidates = generate_candidates(prev)
        isempty(candidates) && break

        next = Vector{Vector{Int}}()
        next_tids = Dict{Vector{Int},BitVector}()
        for candidate in candidates
            ta = prev_tids[candidate[1:end-1]]
            tb = prev_tids[[candidate[1:end-2]; candidate[end]]]
            buffer .= ta .& tb
            support = count(buffer)
            if support >= minsup_count
                result[candidate] = support
                push!(next, candidate)
                next_tids[candidate] = copy(buffer)
            end
        end
        prev = next
        prev_tids = next_tids
    end

    return result
end
