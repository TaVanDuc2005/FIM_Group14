# Bản tối ưu: mỗi item có một tidset dạng BitVector (độ dài = số giao dịch).
# Support của itemset = count(&(tidset của các item)).
# Giữ cùng giao diện với `apriori` để so sánh trực tiếp trong benchmark.
#
# Liên hệ bài báo (Agrawal & Srikant 1994, AprioriTid, Fig. 2 bước 7):
# ứng viên c chứa trong giao dịch t <=> (c - c[k]) và (c - c[k-1]) đều chứa trong t.
# Ở đây điều đó thành phép AND hai tidset của hai (k-1)-itemset sinh ra c.
# CSDL chỉ được quét 2 lần (đếm item, rồi dựng tidset cho item phổ biến);
# từ lượt k = 2 trở đi không đọc lại CSDL nữa.

"""
    build_tidsets(transactions, items) -> Dict{Int,BitVector}

Tạo tidset cho các item trong `items` (thường là các item phổ biến).
Item không phổ biến bị bỏ qua: không tốn `n` bit bộ nhớ cho mỗi item đó.
"""
function build_tidsets(transactions::Vector{Vector{Int}}, items)::Dict{Int,BitVector}
    n = length(transactions)
    tidsets = Dict{Int,BitVector}(item => falses(n) for item in items)

    for (transaction_index, transaction) in enumerate(transactions)
        for item in transaction
            tidset = get(tidsets, item, nothing)
            tidset === nothing || (tidset[transaction_index] = true)
        end
    end

    return tidsets
end

"""
    build_tidsets(transactions) -> Dict{Int,BitVector}

Tạo tidset cho mọi item xuất hiện trong CSDL.
"""
build_tidsets(transactions::Vector{Vector{Int}})::Dict{Int,BitVector} =
    build_tidsets(transactions, unique(Iterators.flatten(transactions)))

"""
    count_items(transactions) -> Dict{Int,Int}

Lần quét đầu tiên: support của từng item. Item lặp lại trong cùng một giao dịch
chỉ được đếm một lần (nhớ chỉ số giao dịch gần nhất đã đếm item đó).
"""
function count_items(transactions::Vector{Vector{Int}})::Dict{Int,Int}
    item_counts = Dict{Int,Int}()
    last_seen = Dict{Int,Int}()
    for (transaction_index, transaction) in enumerate(transactions), item in transaction
        get(last_seen, item, 0) == transaction_index && continue
        last_seen[item] = transaction_index
        item_counts[item] = get(item_counts, item, 0) + 1
    end
    return item_counts
end

"""
    and_count!(dest, a, b) -> Int

`dest .= a .& b` rồi trả về số bit 1, thao tác trực tiếp trên các word 64 bit
(`BitVector.chunks`) để tránh kiểm tra biên và broadcast trong vòng lặp nóng.
"""
function and_count!(dest::BitVector, a::BitVector, b::BitVector)::Int
    dc, ac, bc = dest.chunks, a.chunks, b.chunks
    total = 0
    @inbounds @simd for i in eachindex(dc, ac, bc)
        w = ac[i] & bc[i]
        dc[i] = w
        total += count_ones(w)
    end
    return total
end

"""
    apriori_bitarray(transactions, minsup) -> Dict{Vector{Int},Int}
"""
function apriori_bitarray(transactions::Vector{Vector{Int}}, minsup::Real)::Dict{Vector{Int},Int}
    minsup_count = min_support_count(minsup, length(transactions))
    item_counts = count_items(transactions)
    frequent_items = sort!([item for (item, c) in item_counts if c >= minsup_count])
    tidsets = build_tidsets(transactions, frequent_items)

    result = Dict{Vector{Int},Int}()
    # prev[i] là một (k-1)-itemset phổ biến, prev_tids[i] là tidset của nó.
    # prev luôn theo thứ tự từ điển: L1 đã sắp, và generate_candidates_with_parents
    # sinh ứng viên theo thứ tự từ điển nên L(k) lọc ra từ đó cũng đã sắp.
    prev = [[item] for item in frequent_items]
    prev_tids = [tidsets[item] for item in frequent_items]
    for item in frequent_items
        result[[item]] = item_counts[item]
    end

    buffer = falses(length(transactions))
    while !isempty(prev)
        candidates, parents = generate_candidates_with_parents(prev)
        isempty(candidates) && break

        next = Vector{Vector{Int}}()
        next_tids = Vector{BitVector}()
        for (candidate, (i, j)) in zip(candidates, parents)
            # tid(c) = tid(cha 1) AND tid(cha 2) (AprioriTid, Fig. 2 bước 7).
            support = and_count!(buffer, prev_tids[i], prev_tids[j])
            if support >= minsup_count
                result[candidate] = support
                push!(next, candidate)
                push!(next_tids, copy(buffer))
            end
        end
        prev = next
        prev_tids = next_tids
    end

    return result
end
