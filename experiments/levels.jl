# Hồ sơ theo từng mức k: |C_k| (ứng viên sau prune), |L_k| (phổ biến), thời gian sinh/đếm.
# Dùng để giải thích nút thắt ở k = 2 và việc C_k tiến sát L_k khi k >= 3 (mục 2.3 tóm tắt bài báo).
# Dùng lại các hàm nội bộ của AprioriFIM (cùng logic với apriori_bitarray).
function level_profile(tx, minsup)
    n = length(tx)
    mc = min_support_count(minsup, n)
    counts = AprioriFIM.count_items(tx)
    items = sort!([i for (i, c) in counts if c >= mc])
    tidsets = AprioriFIM.build_tidsets(tx, items)
    rows = NamedTuple[(k = 1, candidates = length(counts), frequent = length(items), gen_s = 0.0, count_s = 0.0)]
    prev = [[i] for i in items]
    prev_tids = BitVector[tidsets[i] for i in items]
    buffer = falses(n)
    k = 1
    while !isempty(prev)
        k += 1
        g = @timed AprioriFIM.generate_candidates_with_parents(prev)
        candidates, parents = g.value
        if isempty(candidates)
            push!(rows, (k = k, candidates = 0, frequent = 0, gen_s = g.time, count_s = 0.0))
            break
        end
        next = Vector{Vector{Int}}()
        next_tids = BitVector[]
        t = @elapsed for (c, (i, j)) in zip(candidates, parents)
            s = AprioriFIM.and_count!(buffer, prev_tids[i], prev_tids[j])
            if s >= mc
                push!(next, c)
                push!(next_tids, copy(buffer))
            end
        end
        push!(rows, (k = k, candidates = length(candidates), frequent = length(next), gen_s = g.time, count_s = t))
        prev, prev_tids = next, next_tids
    end
    return rows
end
