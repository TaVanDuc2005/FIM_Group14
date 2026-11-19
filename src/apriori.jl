# Apriori cơ bản. TODO: TỰ CÀI ĐẶT (cần hiểu từng bước để vấn đáp).
# Biểu diễn: itemset = Vector{Int} đã sắp tăng dần;
#            kết quả = Dict{Vector{Int},Int} (itemset => support tuyệt đối).

"""
    generate_candidates(prev::Vector{Vector{Int}}) -> Vector{Vector{Int}}

Bước join (ghép hai (k-1)-itemset chung k-2 item đầu) rồi prune
(loại ứng viên có tập con (k-1) không phổ biến). `prev` phải gồm các itemset
cùng kích thước và được sắp xếp theo thứ tự từ điển.
"""
function generate_candidates(prev::Vector{Vector{Int}})::Vector{Vector{Int}}
    previous_itemsets = Set(prev)
    candidates = Vector{Vector{Int}}()

    for i in eachindex(prev)
        a = prev[i]
        length(a) > 0 || continue

        for j in (i + 1):length(prev)
            b = prev[j]
            a[1:end-1] == b[1:end-1] || break
            a[end] < b[end] || continue

            candidate = [a; b[end]]
            all_subsets_frequent = true
            for item_index in eachindex(candidate)
                subset = [candidate[1:item_index-1]; candidate[item_index+1:end]]
                if !(subset in previous_itemsets)
                    all_subsets_frequent = false
                    break
                end
            end

            if all_subsets_frequent
                push!(candidates, candidate)
            end
        end
    end

    return candidates
end

"""
    count_support(candidates, transactions) -> Dict{Vector{Int},Int}

Quét CSDL, đếm số giao dịch chứa từng ứng viên.
"""
function count_support(candidates::Vector{Vector{Int}},
                       transactions::Vector{Vector{Int}})::Dict{Vector{Int},Int}
    support = Dict{Vector{Int},Int}(candidate => 0 for candidate in candidates)
    transaction_sets = [Set(transaction) for transaction in transactions]

    for candidate in keys(support)
        for transaction in transaction_sets
            issubset(candidate, transaction) && (support[candidate] += 1)
        end
    end

    return support
end

"""
    apriori(transactions, minsup) -> Dict{Vector{Int},Int}

Trả về mọi tập phổ biến với support tuyệt đối. `minsup` là tỉ lệ hoặc số đếm.
"""
function apriori(transactions::Vector{Vector{Int}}, minsup::Real)::Dict{Vector{Int},Int}
    minsup_count = min_support_count(minsup, length(transactions))
    result = Dict{Vector{Int},Int}()

    item_counts = Dict{Int,Int}()
    for transaction in transactions
        for item in Set(transaction)
            item_counts[item] = get(item_counts, item, 0) + 1
        end
    end

    prev = Vector{Vector{Int}}()
    for item in sort!(collect(keys(item_counts)))
        support = item_counts[item]
        if support >= minsup_count
            itemset = [item]
            result[itemset] = support
            push!(prev, itemset)
        end
    end

    while !isempty(prev)
        sort!(prev)
        candidates = generate_candidates(prev)
        isempty(candidates) && break

        candidate_support = count_support(candidates, transactions)
        next = Vector{Vector{Int}}()
        for candidate in candidates
            support = candidate_support[candidate]
            if support >= minsup_count
                result[candidate] = support
                push!(next, candidate)
            end
        end
        prev = next
    end

    return result
end
