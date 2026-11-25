# Apriori cơ bản (Agrawal & Srikant 1994, Fig. 1 và apriori-gen ở mục 2.1.1).
# Biểu diễn: itemset = Vector{Int} đã sắp tăng dần;
#            kết quả = Dict{Vector{Int},Int} (itemset => support tuyệt đối).

"""
    all_subsets_frequent!(subset, candidate, previous_itemsets) -> Bool

Bước prune: mọi (k-1)-tập con của `candidate` phải nằm trong L(k-1).
Bỏ phần tử cuối hoặc kế cuối cho ra chính hai itemset cha đã join (chắc chắn phổ biến),
nên chỉ cần kiểm tra k-2 tập con còn lại. `subset` là buffer độ dài k-1 được dùng lại
cho mọi lần kiểm tra, tránh cấp phát một mảng mới cho mỗi tập con.
"""
function all_subsets_frequent!(subset::Vector{Int}, candidate::Vector{Int},
                               previous_itemsets::Set{Vector{Int}})::Bool
    k = length(candidate)
    for skip in 1:(k - 2)
        pos = 1
        @inbounds for idx in 1:k
            idx == skip && continue
            subset[pos] = candidate[idx]
            pos += 1
        end
        subset in previous_itemsets || return false
    end
    return true
end

"""
    generate_candidates_with_parents(prev) -> (candidates, parents)

apriori-gen: bước join (ghép hai (k-1)-itemset `prev[i]`, `prev[j]` chung k-2 item đầu)
rồi prune. `parents[c] = (i, j)` là chỉ số hai itemset cha của `candidates[c]`, tương ứng
trường *generators* trong mục 2.2.2 của bài báo; bản BitArray dùng nó để lấy tidset của
hai cha theo chỉ số thay vì tra cứu bằng itemset.

`prev` phải gồm các itemset cùng kích thước, sắp theo thứ tự từ điển. Khi đó
`candidates` cũng được sinh ra theo thứ tự từ điển.
"""
function generate_candidates_with_parents(prev::Vector{Vector{Int}})
    previous_itemsets = Set(prev)
    candidates = Vector{Vector{Int}}()
    parents = Vector{Tuple{Int,Int}}()
    (isempty(prev) || isempty(first(prev))) && return candidates, parents
    subset = Vector{Int}(undef, length(first(prev)))

    for i in eachindex(prev)
        a = prev[i]
        for j in (i + 1):length(prev)
            b = prev[j]
            # prev đã sắp xếp: khi tiền tố k-2 item khác nhau thì các j sau cũng khác -> dừng.
            @views a[1:end-1] == b[1:end-1] || break
            a[end] < b[end] || continue

            candidate = [a; b[end]]
            if all_subsets_frequent!(subset, candidate, previous_itemsets)
                push!(candidates, candidate)
                push!(parents, (i, j))
            end
        end
    end

    return candidates, parents
end

"""
    generate_candidates(prev::Vector{Vector{Int}}) -> Vector{Vector{Int}}

Như `generate_candidates_with_parents` nhưng chỉ trả về danh sách ứng viên.
"""
generate_candidates(prev::Vector{Vector{Int}})::Vector{Vector{Int}} =
    first(generate_candidates_with_parents(prev))

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

check_maxlen(maxlen) = maxlen === nothing || maxlen >= 1 ||
    throw(ArgumentError("maxlen phải ≥ 1, nhận $maxlen"))

"""Còn được sinh mức tiếp theo không: các tập trong `prev` có ít hơn `maxlen` item."""
below_maxlen(prev, maxlen) = maxlen === nothing || length(first(prev)) < maxlen

"""
    apriori(transactions, minsup; maxlen = nothing) -> Dict{Vector{Int},Int}

Trả về mọi tập phổ biến với support tuyệt đối. `minsup` là tỉ lệ hoặc số đếm.
`maxlen` (tùy chọn) giới hạn số item tối đa của một tập: thuật toán dừng sau mức `maxlen`.
Kết quả khi đó đúng bằng các tập phổ biến có không quá `maxlen` item.
"""
function apriori(transactions::Vector{Vector{Int}}, minsup::Real;
                 maxlen::Union{Integer,Nothing} = nothing)::Dict{Vector{Int},Int}
    check_maxlen(maxlen)
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

    while !isempty(prev) && below_maxlen(prev, maxlen)
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
